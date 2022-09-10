//
//  File.swift
//  
//
//  Created by Kai on 2022/8/1.
//

import Foundation
import EventKit
import Combine
import UIKit

public class EventManager {
    public let config: TaskConfig
    public let cacheHandlers: CacheHandlers
    
    public let tasksOfKeyResult: Cache<String, [TaskValue]> = .init()
    public var recordsOfKeyResult: Dictionary<String, [RecordValue]> = .init()
    
    public let reloadCaches = PassthroughSubject<Void, Never>()
    public let cachesReloaded = PassthroughSubject<Void, Never>()
    
    /// 使用一个唯一的 eventStore 可能会导致内存泄漏，但目前看来影响不大
    /// 因为每创建一个 EKEvent 实例，会强关联在 EKEventStore 上，可能必须 EKEventStore 释放后，该 EKEvent 才会释放
    /// 解决办法就是每次在创建 EKEvent 的时候重新初始化一个 EKEventStore ，但要注意，保存该 EKEvent 必须要使用创建它的 EKEventStore 实例
    public var eventStore: EKEventStore
    var cancellables = Set<AnyCancellable>()
    var currentRunID: String?
    
    public init(config: TaskConfig, cacheHandlers: CacheHandlers) {
        self.config = config
        self.eventStore = .init()
        self.cacheHandlers = cacheHandlers
        
        setupEventStore()
    }
    
    let queue = DispatchQueue(label: "com.vision.app.events.manager", qos: .userInteractive)
    
    func setupEventStore() {
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .map { _ in }
            .merge(with: reloadCaches.dropFirst())
            .debounce(for: 0.8, scheduler: RunLoop.main)
            .prepend(())
            .map { [unowned self] in
                makeCachePublisher
            }
            /// FIXME: 这里并没有取消到上一个线程里的执行，可能会浪费一点点计算时间
            /// 好在不影响主线程
            .switchToLatest()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                
//                self.tasksOfKeyResult.assignWithDictionary(a)
//                self.recordsOfKeyResult = b
                self.cachesReloaded.send()
            }
            .store(in: &cancellables)
    }
}

public extension EventManager {
    var selectedCalendarIdentifier: String? {
        get { config.userDefaults.string(forKey: "EventKitUtils_selectedCalendarIdentifier") }
        set { config.userDefaults.set(newValue, forKey: "EventKitUtils_selectedCalendarIdentifier") }
    }
    
    var defaultCalendarToSaveEvents: EKCalendar? {
        if let id = selectedCalendarIdentifier,
           let calendar = eventStore.calendar(withIdentifier: id)  {
            return calendar
        }

        return eventStore.defaultCalendarForNewEvents
    }
    
    var isEventStoreAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .authorized
    }
}

public extension EventManager {
    func taskObject(_ task: TaskKind) -> TaskKind? {
        if let task = config.taskById(task.normalizedID) {
            return task
        }
        
        return fetchEvent(withTaskValue: task.value)
    }
    
    func toggleCompletion(_ task: TaskKind) async {
        guard let taskObject = taskObject(task) else {
            return
        }
        
        taskObject.toggleCompletion()
        
        try! await saveTask(taskObject)
    }
    
    func saveTask(_ task: TaskKind, savingRecurence: Bool = false, commit: Bool = true) async throws {
        if task.isValueType, let task = taskObject(task) {
            try await saveTask(task)
        } else if let event = task as? EKEvent {
            try eventStore.save(event, span: savingRecurence ? .futureEvents : .thisEvent, commit: commit)
        } else if task.kindIdentifier == .managedObject {
            await config.saveTask(task.value)
        } else {
            assertionFailure("no such task")
        }
    }
    
    func deleteTask(_ task: TaskKind, deletingRecurence: Bool = false, commit: Bool = true) async {
        if task.isValueType, let task = taskObject(task) {
            await deleteTask(task, deletingRecurence: deletingRecurence)
        } else if let event = task as? EKEvent {
            try! eventStore.remove(event,
                                   span: deletingRecurence ? .futureEvents : .thisEvent,
                                   commit: commit)
        } else if task.kindIdentifier == .managedObject {
            await config.deleteTaskByID(task.normalizedID)
        }
    }
    
    func deleteTasks(_ tasks: [TaskKind]) async {
        let tasks = tasks.uniquedById

        for task in tasks {
            await deleteTask(task, deletingRecurence: true, commit: false)
        }
        
        try! eventStore.commit()
    }
    
    func saveTasks(_ tasks: [TaskKind]) async throws {
        let tasks = tasks.uniquedById
        
        for task in tasks {
            try await saveTask(task, savingRecurence: true, commit: false)
        }
        
        try! eventStore.commit()
    }
    
    func testHasRepeatingTasks(with repeatingInfo: TaskRepeatingInfo) -> Bool {
        let count = config.taskCountWithRepeatingInfo(repeatingInfo)
        
        if count > 1 {
            return true
        }
        
        var foundEvent: EKEvent?
        var isTrue = false
        
        enumerateEventsAndReturnsIfExceedsNonProLimit { event in
            if repeatingInfo == event.repeatingInfo {
                if foundEvent != nil || count == 1 {
                    isTrue = true
                    return true
                }
                        
                foundEvent = event
            }
            
            return false
        }

        return isTrue
    }
    
    func fetchEventTasks(with type: FetchTasksType?, onlyFirst: Bool = false) -> [TaskValue] {
        guard isEventStoreAuthorized else {
            return []
        }
        
        var tasks: [TaskValue] = []
        var ids: Set<String> = []
        
        enumerateEventsAndReturnsIfExceedsNonProLimit { event in
            var flag = false
            
            switch type {
            case nil:
                if !ids.contains(event.normalizedID) {
                    tasks.append(event.value)
                    ids.insert(event.normalizedID)
                }
            case .repeatingInfo(let info):
                if info == event.repeatingInfo {
                    if !onlyFirst || !ids.contains(event.normalizedID) {
                        tasks.append(event.value)
                        
                        if onlyFirst {
                            ids.insert(event.normalizedID)
                        }
                    }
                }
            case .recordValue(let recordValue):
                if let taskID = recordValue.linkedTaskID, let completedAt = recordValue.date {
                    if taskID == event.normalizedID && completedAt == event.completedAt {
                        tasks.append(event.value)
                        
                        flag = true
                    }
                }
            case .segment:
                tasks.append(event.value)
            case .taskID(let id):
                if event.normalizedID == id {
                    tasks.append(event.value)
                }
            }
            
            if onlyFirst && !tasks.isEmpty {
                return true
            }
            
            return flag
        }
        
        return tasks
    }
    
    func fetchTasks(with type: FetchTasksType, fetchingKRInfo: Bool = true, onlyFirst: Bool = false) async -> [TaskValue] {
        var returningFirst = false
        
        var tasks = await withCheckedContinuation { continuation in
            config.fetchNonEventTasks(type) { tasks in
                if onlyFirst, let first = tasks.first {
                    continuation.resume(returning: [first])
                    returningFirst = true
                    return
                }
                
                continuation.resume(returning: tasks)
            }
        }
        
        if returningFirst {
            return tasks
        }
        
        tasks += await cacheHandlers.fetchTaskValues(by: type, firstOnly: onlyFirst)
        
        if fetchingKRInfo {
            for (index, task) in tasks.enumerated() {
                if let krId = task.keyResultId {
                    let krInfo = await config.fetchKeyResultInfo(krId)
                    tasks[index].keyResultInfo = krInfo
                }
            }
        }
        
        return tasks
    }
    
    func fetchFirstTask(with type: FetchTasksType, fetchingKRInfo: Bool = true) async -> TaskValue? {
        await fetchTasks(with: type, fetchingKRInfo: fetchingKRInfo, onlyFirst: true).first
    }
    
    func checkIfExceedsNonProLimit() -> Bool {
        guard !config.isPro else {
            return false
        }
            
        return enumerateEventsAndReturnsIfExceedsNonProLimit()
    }
    
    
    
    @discardableResult
    func enumerateEventsAndReturnsIfExceedsNonProLimit(matching precidate: NSPredicate? = nil, handler: ((EKEvent) -> Bool)? = nil) -> Bool {
        var deferredAction: (() -> Void)?
        
        if #available(iOS 15.0, *) {
            let key: StaticString = "enumerateEventsAndReturnsIfExceedsNonProLimit"
            let signpostID = Self.signposter.makeSignpostID()
            let state = Self.signposter.beginInterval(key, id: signpostID)
            
            deferredAction = {
                Self.signposter.endInterval(key, state)
            }
        }
        
        defer {
            deferredAction?()
        }
        
        var enumeratedRepeatingInfoSet: Set<TaskRepeatingInfo> = []
        var exceededNonProLimit = false
        
        let predicate = precidate ?? eventsPredicate()
        
        eventStore.enumerateEvents(matching: predicate) { [unowned self] event, pointer in
            guard event.url?.host == self.config.eventBaseURL.host else {
                return
            }
            
            if let nonProLimit = config.maxNonProLimit() {
                if !exceededNonProLimit {
                    enumeratedRepeatingInfoSet.insert(event.repeatingInfo)
                }
                
                if enumeratedRepeatingInfoSet.count == nonProLimit {
                    exceededNonProLimit = true
                }
            }
            
            if handler?(event) == true {
                pointer.pointee = true
            }
        }
        
        return exceededNonProLimit
    }
    
    func fetchOrCreateTaskObject(from taskValue: TaskValue? = nil) -> TaskKind? {
        if let task = taskValue {
            return self.taskObject(task)
        }
        
        var taskObject = config.createNonEventTask()
        taskObject.isDateEnabled = true
        
        return taskObject
    }
    
    func postpondTasks(_ tasks: [TaskValue], fetchingMore: Bool = true) async {
        var afterTasks: [TaskKind] = []
        
        for task in tasks {
            var taskObject = taskObject(task)!
            taskObject.postpone()
            afterTasks.append(taskObject)
            
            if fetchingMore {
                let moreOverduedTasks = await fetchTasks(with: .repeatingInfo(task.repeatingInfo), onlyFirst: false)
                    .filter { $0.state == .overdued }
                await postpondTasks(moreOverduedTasks, fetchingMore: false)
            }
        }
        
        try! await saveTasks(afterTasks)
    }
}

extension EventManager {
    func eventsPredicate() -> NSPredicate {
        let calendars = eventStore.calendars(for: .event).filter({ $0.allowsContentModifications && !$0.isSubscribed })
        let predicate = eventStore.predicateForEvents(withStart: config.eventRequestRange.lowerBound,
                                                      end: config.eventRequestRange.upperBound,
                                                      calendars: calendars)
        
        return predicate
    }
    
    func fetchEvent(withTaskValue task: TaskValue) -> EKEvent? {
        /// 若 event 不是重复事件，则可以直接用 id 拿到
        if let event = eventStore.event(withIdentifier: task.normalizedID),
           !event.hasRecurrenceRules {
            return event
        }
        
        var foundEvent: EKEvent?
        
        enumerateEventsAndReturnsIfExceedsNonProLimit { event in
            if event.value.isSameTaskValueForRepeatTasks(with: task) {
                foundEvent = event
                
                return true
            }
            
            return false
        }
        
        return foundEvent
    }
}

fileprivate extension TaskConfig {
    var userDefaults: UserDefaults {
        if let appGroup = appGroup,
        let userDefaults = UserDefaults(suiteName: appGroup) {
            return userDefaults
        }
        
        return UserDefaults.standard
    }
}
