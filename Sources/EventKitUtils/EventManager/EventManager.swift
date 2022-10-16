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
    public let reloadCaches = PassthroughSubject<Void, Never>()
    public let cachesReloaded = PassthroughSubject<Void, Never>()
    
    lazy var generator = UINotificationFeedbackGenerator()
    
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
            .filter { [unowned self] in isEventStoreAuthorized }
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
    
    #warning("problematic")
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
    
    var isNotFirstOpenEventSettings: Bool {
        get { configuration.userDefaults.bool(forKey: "isNotFirstOpenEventSettings") }
        set { configuration.userDefaults.set(newValue, forKey: "isNotFirstOpenEventSettings") }
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
    /// Toggle the completion status of the task
    ///
    /// You should implement an Optimistic UI mechanism to use this method, due to this method requires a quick time interval to complete, while the toggling UI should be smooth for user.
    ///
    /// Suggestion: use it in the background queue.
    /// - Parameter task: the task kind to toggle completion
    func toggleCompletion(_ task: TaskValue) async throws {
        // for local tasks
        var task = task
        task.toggleCompletion()
        
        Task {
            await generator.notificationOccurred(.success)
        }
        
        try await saveTask(task)
    }
    
    func toggleAbortion(_ task: TaskValue) async {
        var task = task
        task.toggleAbortion()
        
        try! await saveTask(task)
    }
    
    func toggleTasksAbortion(_ tasks: [TaskKind]) async throws {
        assert(!tasks.isEmpty)
        
        let uniquedTasks = tasks.uniquedById
        
        for task in uniquedTasks {
            var task = task
            task.toggleAbortion()
            
            // task abortion may start from not the first recrrence of the task
            // therefore cannot use firstRecurrence to find the first recurrence to save
            try await saveTask(task, savingRecurrences: true, commit: false)
        }
        
        try eventStore.commit()
    }
    
    /// Save the Task
    /// - Parameters:
    ///   - task: the ``TaskKind`` to save
    ///   - savingRecurence: should save the recurrences
    ///   - commit: should commit to the EKEventStore
    func saveTask(_ task: TaskKind, savingRecurrences: Bool = false, commit: Bool = true) async throws {
        let taskValue = task.value

        if var event = task as? EKEvent {
            if savingRecurrences, let firstRecurrence = eventStore.event(withIdentifier: event.normalizedID) {
                // save the first recurrence and its future events
                event = firstRecurrence
                // when assign dates, only time of the dates should assign, for this event may not be the first recurrence, which should not change its date.
                event.assignFromTaskKind(taskValue, onlyAssignDatesTime: true)
            }
            
            try eventStore.save(event,
                                span: savingRecurrences && !event.isDetached ? .futureEvents : .thisEvent,
                                commit: commit)
            return
        }
        
        if let task = task as? TaskValue {
            if task.kindIdentifier == .managedObject {
                await configuration.saveNonEventTask(task.value)
                return
            }
            
            if var event = await fetchEvent(withTaskValue: task, firstRecurrence: false)  {
                event.assignFromTaskKind(taskValue, onlyAssignDatesTime: true)
                try eventStore.save(event,
                                    span: savingRecurrences && !event.isDetached ? .futureEvents : .thisEvent,
                                    commit: commit)
                return
            }
        }
        
        assertionFailure("no such task")
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
        if task.kindIdentifier == .managedObject {
            await configuration.deleteNonEventTask(byID: task.normalizedID)
            return
        }
        
        if let task = task as? TaskValue {
            if var event = await fetchEvent(withTaskValue: task, firstRecurrence: deletingRecurrences) {
                if deletingRecurrences {
                    // delete the first recurrence and its future events
                    event = eventStore.event(withIdentifier: event.normalizedID)!
                }
                
                try! eventStore.remove(event,
                                       span: deletingRecurrences && !event.isDetached ? .futureEvents : .thisEvent,
                                       commit: commit)
                return
            }
        }
        
        assertionFailure("no such task")
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
        let tasks = tasks.uniquedById
        
        for task in tasks {
            await deleteTask(task, deletingRecurrences: true, commit: false)
        }
        
        try! eventStore.commit()
    }
    
    func saveTasks(_ tasks: [TaskKind], savingRecurrences: Bool = true) async throws {
        for task in tasks {
            if let task = task as? TaskValue {
                assert(task.oldDateInterval != nil)
            }
            
            try await saveTask(task, savingRecurrences: savingRecurrences, commit: false)
        }
        
        try eventStore.commit()
    }
    
    /// The public API for fetching tasks
    /// - Parameters:
    ///   - type: the ``FetchTasksType`` to fetch
    ///   - fetchingKRInfo: if fetches ``KeyResultInfo``
    /// - Returns: a ``FetchedTaskResult``
    func fetchTasks(with type: FetchTasksType, fetchingKRInfo: Bool = false) async -> FetchedTaskResult {
        if case .recordValue(let recordValue) = type {
            guard let event = eventStore.event(withIdentifier: recordValue.normalizedID) else {
                return .init()
            }
            
            return .init(tasks: [event.value], completedTaskCounts: [:])
        }
        
        let includingCounts = type.shouldIncludeCounts
        
        var fetchedTaskResult = await configuration.fetchNonEventTasks(type: type, includingCounts: includingCounts) ?? .init()
        if let fetchedEventTaskResult = await cacheManager.handlers.fetchTaskValues(by: type, includingCounts: includingCounts) {
            fetchedTaskResult = fetchedTaskResult.merged(with: fetchedEventTaskResult, mergingByRepeatingInfoWithState: type.shouldMergeTasks)
        }
        
        if fetchingKRInfo {
            for (index, task) in fetchedTaskResult.tasks.enumerated() {
                if let krId = task.keyResultId {
                    let krInfo = await configuration.fetchKeyResultInfo(byID: krId)
                    fetchedTaskResult.tasks[index].keyResultInfo = krInfo
                }
            }
        }
        
        return fetchedTaskResult
    }
    
    func checkIfKeyResultHasLinkedTasks(keyResultID: String) async -> Bool {
        if await cacheManager.handlers.fetchTasksCount(withKeyResultID: keyResultID) > 0 {
            return true
        }
        
        return await configuration.fetchNonEventTaskCount(withKeyResultID: keyResultID) > 0
    }
    
    /// Check the total number of EKEvents exceeds the limit for non Pro users
    /// - Returns: the boolean that indicates if events
    func checkIfExceedsNonProLimit() async -> Bool {
        guard !configuration.isPro else {
            return false
        }
            
        return await EventEnumerator(eventManager: self).enumerateEventsAndReturnsIfExceedsNonProLimit()
    }
    
    func testIsRepeating(_ taskValue: TaskValue) async -> Bool {
        if let count = await configuration.fetchNonEventTaskCount(withRepeatingInfo: taskValue.repeatingInfo),
           count > 0 {
            return true
        }
        
        guard let tasks = await cacheManager.handlers.fetchTaskValues(by: .repeatingInfo(taskValue.repeatingInfo))?.tasks else {
            return false
        }
        
        return tasks.count > 0
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
                .tasks
                .filter { $0.state == .overdued }
            
            for task in moreOverduedTasks {
                if var event = await fetchEvent(withTaskValue: task, firstRecurrence: false) {
                    event.postpone()
                    afterTasks.append(event)
                } else if var nonEventTask = await configuration.fetchNonEventTask(byID: task.normalizedID) {
                    nonEventTask.postpone()
                    afterTasks.append(nonEventTask)
                }
            }
        }
        
        try! await saveTasks(afterTasks, savingRecurrences: false)
    }
    
    /// Fetch EKEvent instance by ``TaskValue``
    ///
    /// ⚠️ The task here to fetch event with, its date time may be changed, therefore won't be found by this method.
    ///
    /// Narrow down the date range of events, improving the performance
    /// - Parameter task: the ``TaskValue``
    /// - Parameter firstRecurrence: is fetching the first recurrence of the events if it has recurrences
    /// - Returns: an Optional ``EKEvent``
    func fetchEvent(withTaskValue task: TaskValue, firstRecurrence: Bool) async -> EKEvent? {
        // 若 event 不是重复事件，则可以直接用 id 拿到
        if firstRecurrence {
            if let event = eventStore.event(withIdentifier: task.normalizedID),
                event.hasRecurrenceRules &&
                !event.isDetached {
                return event
            }
        }
        
        guard let startDate = task.oldDateInterval?.start ?? task.normalizedStartDate,
              let endDate = task.oldDateInterval?.end ?? task.normalizedEndDate else {
            return nil
        }
        
        let eventEnumerator = EventEnumerator(eventManager: self)
        #warning("the interval may be large")
        let offsetStartDate = Calendar.current.date(byAdding: .day, value: -1, to: startDate)!
        let offsetEndDate = Calendar.current.date(byAdding: .day, value: 1, to: endDate)!
        let interval = DateInterval(start: offsetStartDate, end: offsetEndDate)
        
        var foundEvent: EKEvent?
        
        await eventEnumerator.enumerateEventsAndReturnsIfExceedsNonProLimit(matching: interval) { event, completion in
            guard task.isSameTaskValueForRepeatTasks(as: event.value) else {
                return
            }

            foundEvent = event
            completion()
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
