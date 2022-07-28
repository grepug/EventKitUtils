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
    
    func fetchEvent(withTaskValue task: TaskValue) -> EKEvent? {
        let predicate = eventsPredicate()
        var foundEvent: EKEvent?
        
        eventStore.enumerateEvents(matching: predicate) { event, pointer in
            if event.value == task {
                foundEvent = event
                pointer.pointee = true
            }
        }
        
        return foundEvent
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
    
    func deleteTask(_ task: TaskKind) {
        if let event = task as? EKEvent {
            try! eventStore.remove(event, span: .thisEvent, commit: true)
        } else if let task = task as? ManagedObject {
            task.delete()
        } else {
            assertionFailure("cannot delete task value")
        }
    }
    
    func deleteTasks(_ tasks: [TaskKind]) {
        for task in tasks {
            deleteTask(task)
        }
    }
}

extension TaskHandler {
    func eventsPredicate() -> NSPredicate {
        let calendar = eventStore.defaultCalendarForNewEvents!
        let predicate = eventStore.predicateForEvents(withStart: config.eventRequestRange.lowerBound,
                                                      end: config.eventRequestRange.upperBound,
                                                      calendars: [calendar])
        
        return predicate
    }
}
