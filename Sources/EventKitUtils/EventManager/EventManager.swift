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
    public var config: TaskConfig
    public let tasksOfKeyResult: Cache<String, [TaskValue]> = .init()
    public var recordsOfKeyResult: Dictionary<String, [RecordValue]> = .init()
    
    public let reloadCaches = PassthroughSubject<Void, Never>()
    public let cachesReloaded = PassthroughSubject<Void, Never>()
    
    public var eventStore: EKEventStore
    var cancellables = Set<AnyCancellable>()
    
    public init(config: TaskConfig) {
        self.config = config
        self.eventStore = .init()
        setupEventStore()
    }
    
    func setupEventStore() {
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .map { _ in }
            .merge(with: reloadCaches.dropFirst())
            .prepend(())
            .map { [unowned self] in
                valuesByKeyResultID
                    .compactMap { $0 }
            }
            /// FIXME: 这里并没有取消到上一个线程里的执行，可能会浪费一点点计算时间
            /// 好在不影响主线程
            .switchToLatest()
            .sink { [unowned self] a, b in
                tasksOfKeyResult.assignWithDictionary(a)
                recordsOfKeyResult = b
                
                DispatchQueue.main.async {
                    self.cachesReloaded.send()
                }
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
        await saveTask(taskObject)
    }
    
    func saveTask(_ task: TaskKind, commit: Bool = true) async {
        if task.isValueType, let task = taskObject(task) {
            await saveTask(task)
        } else if let event = task as? EKEvent {
            do {
                try eventStore.save(event, span: .thisEvent, commit: commit)
            } catch {
                let nsError = error as NSError
                
                switch nsError.code {
                case 1010: return
                default: fatalError("save event task failed: \(nsError.description) code: \(nsError.code)")
                }
            }
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
        for task in tasks {
            await deleteTask(task, deletingRecurence: true, commit: false)
        }
        
        try! eventStore.commit()
    }
    
    func saveTasks(_ tasks: [TaskKind]) async {
        for task in tasks {
            await saveTask(task, commit: false)
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
    
    private func fetchTasksAsync(with type: FetchTasksType, onlyFirst: Bool = false, handler: @escaping ([TaskValue]) -> Void) {
        config.fetchNonEventTasks(type) { [unowned self] tasks in
            let tasks = tasks.map(\.value)
            
            if onlyFirst, let first = tasks.first {
                handler([first])
                return
            }
            
            let eventTasks = fetchEventTasks(with: type, onlyFirst: onlyFirst)
            
            handler(tasks + eventTasks)
        }
    }
    
    func fetchEventTasks(with type: FetchTasksType, onlyFirst: Bool = false) -> [TaskValue] {
        guard isEventStoreAuthorized else {
            return []
        }
        
        var tasks: [TaskValue] = []
        
        enumerateEventsAndReturnsIfExceedsNonProLimit { event in
            var flag = false
            
            switch type {
            case .repeatingInfo(let info):
                if info == event.repeatingInfo {
                    tasks.append(event.value)
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
        var tasks = await withCheckedContinuation { continuation in
            fetchTasksAsync(with: type, onlyFirst: onlyFirst) { tasks in
                continuation.resume(returning: tasks)
            }
        }
        
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
                let moreOverduedTasks = await fetchTasks(with: .repeatingInfo(task.repeatingInfo))
                    .filter { $0.state == .overdued }
                await postpondTasks(moreOverduedTasks, fetchingMore: false)
            }
        }
        
        await saveTasks(afterTasks)
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
            if event.value == task {
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
