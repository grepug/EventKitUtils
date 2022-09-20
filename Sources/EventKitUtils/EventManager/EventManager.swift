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
    public let configuration: EventConfiguration
    public let uiConfiguration: EventUIConfiguration?
    public var cacheManager: CacheManager
    
    public let tasksOfKeyResult: Cache<String, [TaskValue]> = .init()
    public var recordsOfKeyResult: Dictionary<String, [RecordValue]> = .init()
    
    public let reloadCaches = PassthroughSubject<Void, Never>()
    public let cachesReloaded = PassthroughSubject<Void, Never>()
    public let cachesReloaded2 = PassthroughSubject<String, Never>()
    
    /// 使用一个唯一的 eventStore 可能会导致内存泄漏，但目前看来影响不大
    /// 因为每创建一个 EKEvent 实例，会强关联在 EKEventStore 上，可能必须 EKEventStore 释放后，该 EKEvent 才会释放
    /// 解决办法就是每次在创建 EKEvent 的时候重新初始化一个 EKEventStore ，但要注意，保存该 EKEvent 必须要使用创建它的 EKEventStore 实例
    public var eventStore: EKEventStore
    var cancellables = Set<AnyCancellable>()
    
    public init(configuration: EventConfiguration, uiConfiguration: EventUIConfiguration, cacheHandlers: CacheHandlers) {
        self.configuration = configuration
        self.uiConfiguration = uiConfiguration
        self.eventStore = .init()
        
        self.cacheManager = .init(eventStore: eventStore,
                                  eventConfiguration: configuration,
                                  handlers: cacheHandlers)
        
        setupEventStore()
    }
    
    let queue = DispatchQueue(label: "com.vision.app.events.manager", qos: .userInteractive)
    
    func setupEventStore() {
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .map { _ in }
            .merge(with: reloadCaches)
            .throttle(for: 1, scheduler: queue, latest: false)
            .prepend(())
            .sink {
                Task {
                    await self.cacheManager.makeCache()
                    self.cachesReloaded.send()
                }
            }
            .store(in: &cancellables)
    }
    
    public func untilNotPending() async {
        if await cacheManager.isPending {
            return await withCheckedContinuation { continuation in
                self.cachesReloaded
                    .prefix(1)
                    .sink { _ in
                        continuation.resume(returning: ())
                    }
                    .store(in: &self.cancellables)
            }
        }
    }
    
}

public extension EventManager {
    var selectedCalendarIdentifier: String? {
        get { configuration.userDefaults.string(forKey: "EventKitUtils_selectedCalendarIdentifier") }
        set { configuration.userDefaults.set(newValue, forKey: "EventKitUtils_selectedCalendarIdentifier") }
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
    func taskObject(_ task: TaskKind) async -> TaskKind? {
        if let task = await configuration.fetchTask(byID: task.normalizedID) {
            return task
        }
        
        return fetchEvent(withTaskValue: task.value)
    }
    
    func toggleCompletion(_ task: TaskKind) async {
        guard let taskObject = await taskObject(task) else {
            return
        }
        
        taskObject.toggleCompletion()
        
        try! await saveTask(taskObject)
    }
    
    func saveTask(_ task: TaskKind, savingRecurence: Bool = false, commit: Bool = true) async throws {
        if task.isValueType, let task = await taskObject(task) {
            try await saveTask(task)
        } else if let event = task as? EKEvent {
            try eventStore.save(event, span: savingRecurence ? .futureEvents : .thisEvent, commit: commit)
        } else if task.kindIdentifier == .managedObject {
            await configuration.saveTask(task.value)
        } else {
            assertionFailure("no such task")
        }
    }
    
    func deleteTask(_ task: TaskKind, deletingRecurence: Bool = false, commit: Bool = true) async {
        if task.isValueType, let task = await taskObject(task) {
            await deleteTask(task, deletingRecurence: deletingRecurence)
        } else if let event = task as? EKEvent {
            try! eventStore.remove(event,
                                   span: deletingRecurence ? .futureEvents : .thisEvent,
                                   commit: commit)
        } else if task.kindIdentifier == .managedObject {
            await configuration.deleteTask(byID: task.normalizedID)
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
    
    func testHasRepeatingTasks(with repeatingInfo: TaskRepeatingInfo) async -> Bool {
        guard let count = await configuration.fetchTaskCount(with: repeatingInfo) else {
            return false
        }
        
        if count > 1 {
            return true
        }
        
        var foundEvent: EKEvent?
        var isTrue = false
        
//        enumerateEventsAndReturnsIfExceedsNonProLimit { event, completion in
//            if repeatingInfo == event.repeatingInfo {
//                if foundEvent != nil || count == 1 {
//                    isTrue = true
//                    completion()
//                    return
//                }
//
//                foundEvent = event
//            }
//        }

        return isTrue
    }
    
    func fetchTasks(with type: FetchTasksType, fetchingKRInfo: Bool = true) async -> [TaskValue] {
        var tasks = await configuration.fetchNonEventTasks(type: type)
        tasks += await cacheManager.handlers.fetchTaskValues(by: type)
        
        if fetchingKRInfo {
            for (index, task) in tasks.enumerated() {
                if let krId = task.keyResultId {
                    let krInfo = await configuration.fetchKeyResultInfo(byID: krId)
                    tasks[index].keyResultInfo = krInfo
                }
            }
        }
        
        return tasks
    }
    
//    func fetchFirstTask(with type: FetchTasksType, fetchingKRInfo: Bool = true) async -> TaskValue? {
//        await fetchTasks(with: type, fetchingKRInfo: fetchingKRInfo, onlyFirst: true).first
//    }
    
    func checkIfExceedsNonProLimit() -> Bool {
        guard !configuration.isPro else {
            return false
        }
            
        return true
//        return enumerateEventsAndReturnsIfExceedsNonProLimit()
    }
    
    
    func fetchOrCreateTaskObject(from taskValue: TaskValue? = nil) async -> TaskKind? {
        if let task = taskValue {
            return await self.taskObject(task)
        }
        
        var taskObject = await configuration.createNonEventTask()
        taskObject.isDateEnabled = true
        
        return taskObject
    }
    
    func postpondTasks(_ tasks: [TaskValue], fetchingMore: Bool = true) async {
        var afterTasks: [TaskKind] = []
        
        for task in tasks {
            var taskObject = await taskObject(task)!
            taskObject.postpone()
            afterTasks.append(taskObject)
            
            if fetchingMore {
                let moreOverduedTasks = await fetchTasks(with: .repeatingInfo(task.repeatingInfo))
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
        let predicate = eventStore.predicateForEvents(withStart: configuration.eventRequestRange.lowerBound,
                                                      end: configuration.eventRequestRange.upperBound,
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
        
//        enumerateEventsAndReturnsIfExceedsNonProLimit { event, completion in
//            if event.value.isSameTaskValueForRepeatTasks(with: task) {
//                foundEvent = event
//                completion()
//                return
//            }
//        }
        
        return foundEvent
    }
}

fileprivate extension EventConfiguration {
    var userDefaults: UserDefaults {
        if let appGroup = appGroupIdentifier,
        let userDefaults = UserDefaults(suiteName: appGroup) {
            return userDefaults
        }
        
        return UserDefaults.standard
    }
}
