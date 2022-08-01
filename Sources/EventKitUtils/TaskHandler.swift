//
//  TaskHandler.swift
//  
//
//  Created by Kai on 2022/7/24.
//

import EventKit
import StorageProvider

protocol TaskHandler {
    var eventStore: EKEventStore { get }
    var config: TaskConfig { get }
}

extension TaskHandler {
    func toggleCompletion(_ task: TaskKind) {
        guard let taskObject = taskObject(task) else {
            return
        }
        
        taskObject.toggleCompletion()
        saveTask(taskObject)
    }
    
    func taskObject(_ task: TaskKind) -> TaskKind? {
        if let task = config.taskById(task.normalizedID) {
            return task
        }
        
        return fetchEvent(withTaskValue: task.value)
    }
    
    func saveTask(_ task: TaskKind) {
        if let event = task as? EKEvent {
            try! eventStore.save(event, span: .thisEvent, commit: true)
        } else if let task = task as? ManagedObject {
            task.save()
        } else if let task = taskObject(task) {
            saveTask(task)
        } else {
            assertionFailure("no such task")
        }
    }
    
    func deleteTask(_ task: TaskKind, deletingRecurence: Bool = false) {
        if let event = task as? EKEvent {
            try! eventStore.remove(event, span: deletingRecurence ? .futureEvents : .thisEvent, commit: true)
        } else if let task = task as? ManagedObject {
            task.delete()
        } else if let task = taskObject(task) {
            deleteTask(task, deletingRecurence: deletingRecurence)
        }
    }
    
    func deleteTasks(_ tasks: [TaskKind]) {
        for task in tasks {
            deleteTask(task, deletingRecurence: true)
        }
    }
    
    func saveTasks(_ tasks: [TaskKind]) {
        for task in tasks {
            saveTask(task)
        }
    }
    
    func enumerateEvents(matching precidate: NSPredicate? = nil, handler: @escaping (EKEvent) -> Bool) {
        guard let predicate = precidate ?? eventsPredicate() else {
            return
        }
        
        eventStore.enumerateEvents(matching: predicate) { event, pointer in
            guard event.url?.host == config.eventBaseURL.host else {
                return
            }
            
            if handler(event) {
                pointer.pointee = true
            }
        }
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
    
    var calendarInUse: EKCalendar? {
        if let id = EventSettingsViewController.selectedCalendarIdentifier,
           let calendar = eventStore.calendar(withIdentifier: id)  {
            return calendar
        }
        
        return eventStore.defaultCalendarForNewEvents
    }
    
    var isEventStoreAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .authorized
    }
    
    func fetchTasksAsync(with type: FetchTasksType, handler: @escaping ([TaskValue]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var tasks: [TaskValue] = []
            
            config.fetchNonEventTasks(type) {
                tasks.append(contentsOf: $0.map(\.value))
            }
            
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
}

fileprivate extension TaskHandler {
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
