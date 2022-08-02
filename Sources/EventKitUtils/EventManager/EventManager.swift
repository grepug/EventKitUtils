//
//  File.swift
//  
//
//  Created by Kai on 2022/8/1.
//

import Foundation
import EventKit
import Combine

public class EventManager {
    var config: TaskConfig
    public let tasksOfKeyResult: Cache<String, [TaskValue]> = .init()
    public let recordsOfKeyResult: Cache<String, [RecordValue]> = .init()
    
    public let reloaded = PassthroughSubject<Void, Never>()
    
    public lazy var eventStore = EKEventStore()
    var cancellables = Set<AnyCancellable>()
    
    public init(config: TaskConfig) {
        self.config = config
        setupEventStore()
    }
    
    func setupEventStore() {
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .map { _ in }
            .prepend(())
            .flatMap { [unowned self] in
                valuesByKeyResultID
                    .compactMap { $0 }
                    .receive(on: DispatchQueue.main)
            }
            .sink { [unowned self] a, b in
                tasksOfKeyResult.assignWithDictionary(a)
                recordsOfKeyResult.assignWithDictionary(b)
                
                reloaded.send()
            }
            .store(in: &cancellables)
    }
}

extension EventManager {
    var selectedCalendarIdentifier: String? {
        get { config.userDefaults.string(forKey: "EventKitUtils_selectedCalendarIdentifier") }
        set { config.userDefaults.set(newValue, forKey: "EventKitUtils_selectedCalendarIdentifier") }
    }
    
    var calendarInUse: EKCalendar? {
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

extension EventManager {
    func taskObject(_ task: TaskKind) -> TaskKind? {
        if let task = config.taskById(task.normalizedID) {
            return task
        }
        
        return fetchEvent(withTaskValue: task.value)
    }
    
    func toggleCompletion(_ task: TaskKind) {
        guard let taskObject = taskObject(task) else {
            return
        }
        
        taskObject.toggleCompletion()
        saveTask(taskObject)
    }
    
    func saveTask(_ task: TaskKind, commit: Bool = true) {
        if let event = task as? EKEvent {
            try! eventStore.save(event, span: .thisEvent, commit: commit)
        } else if task.kindIdentifier == .managedObject {
            config.saveTask(task)
        } else if task.kindIdentifier == .value, let task = taskObject(task) {
            saveTask(task)
        } else {
            assertionFailure("no such task")
        }
    }
    
    func deleteTask(_ task: TaskKind, deletingRecurence: Bool = false, commit: Bool = true) {
        if let event = task as? EKEvent {
            try! eventStore.remove(event, span: deletingRecurence ? .futureEvents : .thisEvent, commit: commit)
        } else if task.kindIdentifier == .managedObject {
            config.deleteTask(task)
        } else if task.kindIdentifier == .value, let task = taskObject(task) {
            deleteTask(task, deletingRecurence: deletingRecurence)
        }
    }
    
    func deleteTasks(_ tasks: [TaskKind]) {
        for task in tasks {
            deleteTask(task, deletingRecurence: true, commit: false)
        }
        
        try! eventStore.commit()
    }
    
    func saveTasks(_ tasks: [TaskKind]) {
        for task in tasks {
            saveTask(task, commit: false)
        }
        
        try! eventStore.commit()
    }
    
    func testHasRepeatingTasks(with task: TaskKind) -> Bool {
        if config.testHasRepeatingTask(task) {
            return true
        }
        
        var foundEvent: EKEvent?
        var isTrue = false
        
        enumerateEvents { event in
            if event.normalizedTitle == task.normalizedTitle {
                if foundEvent != nil {
                    isTrue = true
                    return true
                }
                        
                foundEvent = event
            }
            
            return false
        }

        return isTrue
    }
    
    func fetchTasksAsync(with type: FetchTasksType, handler: @escaping ([TaskValue]) -> Void) {
        config.fetchNonEventTasks(type) { [unowned self] tasks in
            var tasks = tasks.map(\.value)
            
            if isEventStoreAuthorized {
                enumerateEvents { event in
                    switch type {
                    case .title(let title):
                        if title == event.normalizedTitle {
                            tasks.append(event.value)
                        }
                    default:
                        tasks.append(event.value)
                    }
                    
                    return false
                }
            }
            
            handler(tasks)
        }
    }
    
    func enumerateEvents(matching precidate: NSPredicate? = nil, handler: @escaping (EKEvent) -> Bool) {
        guard let predicate = precidate ?? eventsPredicate() else {
            return
        }
        
        eventStore.enumerateEvents(matching: predicate) { event, pointer in
            guard event.url?.host == self.config.eventBaseURL.host else {
                return
            }
            
            if handler(event) {
                pointer.pointee = true
            }
        }
    }
}

extension EventManager {
    func eventsPredicate() -> NSPredicate? {
        guard let calendar = calendarInUse else {
            return nil
        }
        
        let predicate = eventStore.predicateForEvents(withStart: config.eventRequestRange.lowerBound,
                                                      end: config.eventRequestRange.upperBound,
                                                      calendars: [calendar])
        
        return predicate
    }
    
    func fetchEvent(withTaskValue task: TaskValue) -> EKEvent? {
        /// 若 event 不是重复事件，则可以直接用 id 拿到
        if let event = eventStore.event(withIdentifier: task.normalizedID),
           !event.hasRecurrenceRules {
            return event
        }
        
        var foundEvent: EKEvent?
        
        enumerateEvents { event in
            if event.value == task {
                foundEvent = event
                
                return true
            }
            
            return false
        }
        
        return foundEvent
    }
}