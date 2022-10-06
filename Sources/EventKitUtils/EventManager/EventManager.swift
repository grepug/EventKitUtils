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
    
    let generator: UINotificationFeedbackGenerator
    
    /// the singleton of ``EventStore``
    ///
    /// - 使用一个唯一的 eventStore 可能会导致内存泄漏，但目前看来影响不大
    /// - 因为每创建一个 EKEvent 实例，会强关联在 EKEventStore 上，可能必须 EKEventStore 释放后，该 EKEvent 才会释放
    /// - 解决办法就是每次在创建 EKEvent 的时候重新初始化一个 EKEventStore ，但要注意，保存该 EKEvent 必须要使用创建它的 EKEventStore 实例
    public var eventStore: EKEventStore
    
    var cancellables = Set<AnyCancellable>()
    
    public init(configuration: EventConfiguration, uiConfiguration: EventUIConfiguration? = nil, cacheHandlers: CacheHandlers) {
        self.configuration = configuration
        self.uiConfiguration = uiConfiguration
        self.eventStore = .init()
        
        self.cacheManager = .init(eventStore: eventStore,
                                  eventConfiguration: configuration,
                                  handlers: cacheHandlers)
        self.generator = .init()
        
        setupEventStore()
        generator.prepare()
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
                    
                    let isMakingCache = await self.cacheManager.isPending
                    if !isMakingCache {
                        self.cachesReloaded.send()
                    }
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
    
    var isDefaultSyncingToCalendarEnabled: Bool {
        get { configuration.userDefaults.bool(forKey: "isDefaultSyncingToCalendarEnabled") }
        set { configuration.userDefaults.set(newValue, forKey: "isDefaultSyncingToCalendarEnabled") }
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
    /// Get the instance of ``EKEvent``, or ``NSManagedObject``from local task of the ``TaskKind``
    /// - Parameters:
    ///   - task: the other instance of ``TaskKind``
    ///   - firstRecurrence: a boolean indicates whether get the first recurrence of the task
    ///   - creating: is creating a new object
    /// - Returns: a reference type of ``TaskKind``
    func taskObject(_ task: TaskKind, firstRecurrence: Bool = false, creating: Bool = false) async -> TaskKind? {
        // return itself if it is an EKEvent
        if let task = task as? EKEvent {
            return task
        }
        
        if let task = await configuration.fetchNonEventTask(byID: task.normalizedID, creating: creating) {
            return task
        }
        
        return fetchEvent(withTaskValue: task.value, firstRecurrence: firstRecurrence)
    }
    
    /// Toggle the completion status of the task
    ///
    /// You should implement an Optimistic UI mechanism to use this method, due to this method requires a quick time interval to complete, while the toggling UI should be smooth for user.
    ///
    /// Suggestion: use it in the background queue.
    /// - Parameter task: the task kind to toggle completion
    func toggleCompletion(_ task: TaskKind) async throws {
        guard let taskObject = await taskObject(task) else {
            assertionFailure()
            return
        }
        
        taskObject.toggleCompletion()
        
        Task {
            await generator.notificationOccurred(.success)
        }
        
        try await saveTask(taskObject)
    }
    
    func toggleAbortion(_ task: TaskKind) async {
        guard var taskObject = await taskObject(task) else {
            assertionFailure()
            return
        }
        
        taskObject.toggleAbortion()
        
        try! await saveTask(taskObject)
    }
    
    func abortTasks(_ tasks: [TaskKind]) async throws {
        let tasks = tasks.uniquedById
        
        for task in tasks {
            guard var taskObject = await taskObject(task) else {
                assertionFailure()
                continue
            }
            
            taskObject.toggleAbortion()
            
            try await saveTask(taskObject, savingRecurrences: true, commit: false)
        }
        
        try eventStore.commit()
    }
    
    /// Save the Task
    /// - Parameters:
    ///   - task: the task kind to save
    ///   - savingRecurence: should save the recurrences
    ///   - commit: should commit to the EKEventStore
    func saveTask(_ task: TaskKind, savingRecurrences: Bool = false, commit: Bool = true, creating: Bool = false) async throws {
        if task.isValueType, let task = await taskObject(task, firstRecurrence: savingRecurrences, creating: creating) {
            try await saveTask(task)
        } else if let event = task as? EKEvent {
            try eventStore.save(event, span: savingRecurrences ? .futureEvents : .thisEvent, commit: commit)
        } else if task.kindIdentifier == .managedObject {
            await configuration.saveNonEventTask(task.value)
        } else {
            assertionFailure("no such task")
        }
    }
    
    /// Delete a task
    ///
    /// The task kind can be ``TaskValue``, ``EKEvent``. If delete a ``TaskValue``, you should firstly find the real object to this value, which should also be a ``TaskKind``.
    ///
    /// - Parameters:
    ///   - task: the task kind to delete
    ///   - deletingRecurence: should delete the recurrences
    ///   - commit: should commit to the EKEventStore
    func deleteTask(_ task: TaskKind, deletingRecurrences: Bool = false, commit: Bool = true) async {
        if task.isValueType, let task = await taskObject(task, firstRecurrence: deletingRecurrences) {
            await deleteTask(task, deletingRecurrences: deletingRecurrences)
        } else if var event = task as? EKEvent {
            if deletingRecurrences {
                // delete the first recurrence and its future events
                event = eventStore.event(withIdentifier: event.normalizedID)!
            }
            
            try! eventStore.remove(event,
                                   span: deletingRecurrences ? .futureEvents : .thisEvent,
                                   commit: commit)
        } else if task.kindIdentifier == .managedObject {
            await configuration.deleteNonEventTask(byID: task.normalizedID)
        } else {
            assertionFailure()
        }
    }
    
    /// Delete tasks
    ///
    /// Types of deleting tasks
    ///   - Trailing swiping / Opening Context Menu on the TaskList cell, which may delete recurrences
    ///   - Trailing swiping / Opening Context Menu on the TaskList cell (Recurrence Task List), which delete only this task
    ///   - Delete Task button in the ``TaskEditorViewController``, which delete this Task and the recurrences
    ///   - Cancel button in the  navbar of ``TaskEditorViewController``, which delete only this task only when creating
    /// Regroup the array of task kinds into four types:
    ///   - non event tasks
    ///   - the first recurrence of the ``EKEvent``, if any, removing the rest
    ///   - the first recurrence of the ``EKEvent`` in this array
    ///   - the detached EKEvents
    ///
    ///  In the implementation, we unique tasks by their IDs. Because a set of repeating events share a **same** ID, we can find the first recurrence by calling ``EventStore.event(withIdentifier:)``, and delete the first recurrence and its future events.
    /// - Parameter tasks: task kinds to delete
    func deleteTasks(_ tasks: [TaskKind]) async {
        let tasks = tasks.uniquedByIdIgnoringRecurrenceID
        
        print("taskscount", tasks.count, tasks.map(\.normalizedID))

        for task in tasks {
            await deleteTask(task, deletingRecurrences: true, commit: false)
        }
        
        try! eventStore.commit()
    }
    
    func saveTasks(_ tasks: [TaskKind], savingRecurrences: Bool = true) async throws {
        var tasks = tasks
        
        if savingRecurrences {
            tasks = tasks.uniquedById
        }
        
        for task in tasks {
            try await saveTask(task, savingRecurrences: savingRecurrences, commit: false)
        }
        
        try eventStore.commit()
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
    
    /// Check the total number of EKEvents exceeds the limit for non Pro users
    /// - Returns: the boolean that indicates if events
    func checkIfExceedsNonProLimit() -> Bool {
        guard !configuration.isPro else {
            return false
        }
            
        return EventEnumerator(eventManager: self).enumerateEventsAndReturnsIfExceedsNonProLimit()
    }
    
    func testIsRepeating(_ taskValue: TaskValue) async -> Bool {
        if let count = await configuration.fetchNonEventTaskCount(with: taskValue.repeatingInfo),
           count > 0{
            return true
        }
        
        return await cacheManager.handlers.fetchTaskValues(by: .repeatingInfo(taskValue.repeatingInfo)).count > 0
    }
    
    func fetchOrCreateTaskObject(from taskValue: TaskValue? = nil) async -> TaskKind? {
        if let task = taskValue {
            return await self.taskObject(task)
        }
        
        var taskObject = await configuration.createNonEventTask()
        taskObject.isDateEnabled = true
        
        return taskObject
    }
    
    /// Postpond tasks
    ///
    /// Fetch more overdued tasks with each task's repeating info to postpone
    /// - Parameters:
    ///   - tasks: tasks to postpond
    func postponeTasks(_ tasks: [TaskValue]) async {
        var afterTasks: [TaskKind] = []
        
        for task in tasks {
            let moreOverduedTasks = await fetchTasks(with: .repeatingInfo(task.repeatingInfo))
                .filter { $0.state == .overdued }
            
            for task in moreOverduedTasks {
                var taskObject = await taskObject(task)!
                taskObject.postpone()
                afterTasks.append(taskObject)
            }
        }
        
        try! await saveTasks(afterTasks, savingRecurrences: false)
    }
}

extension EventManager {
    /// Fetch EKEvent instance by ``TaskValue``
    ///
    /// Narrow down the date range of events, improving the performance
    /// - Parameter task: the ``TaskValue``
    /// - Returns: an Optional ``EKEvent``
    func fetchEvent(withTaskValue task: TaskValue, firstRecurrence: Bool) -> EKEvent? {
        // 若 event 不是重复事件，则可以直接用 id 拿到
        if let event = eventStore.event(withIdentifier: task.normalizedID) {
            if firstRecurrence || !event.hasRecurrenceRules {
                return event
            }
        }
        
        guard let startDate = task.normalizedStartDate,
              let endDate = task.normalizedEndDate else {
            return nil
        }
        
        let eventEnumerator = EventEnumerator(eventManager: self)
        let offsetStartDate = Calendar.current.date(byAdding: .day, value: -1, to: startDate)!
        let offsetEndDate = Calendar.current.date(byAdding: .day, value: 1, to: endDate)!
        let interval = DateInterval(start: offsetStartDate, end: offsetEndDate)
        
        var foundEvent: EKEvent?
        
        eventEnumerator.enumerateEventsAndReturnsIfExceedsNonProLimit(matching: interval) { event, completion in
            if event.value.isSameTaskValueForRepeatTasks(with: task) {
                foundEvent = event
                completion()
                return
            }
        }
        
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
