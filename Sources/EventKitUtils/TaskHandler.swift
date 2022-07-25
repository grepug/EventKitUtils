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
    func fetchTask(byId id: String) -> TaskKind? {
        if let task = config.taskById(id) {
            return task
        }
        
        return eventStore.event(withIdentifier: id)
    }
    
    func saveTask(_ task: TaskKind) {
        if let event = task as? EKEvent {
            try! eventStore.save(event, span: .thisEvent, commit: true)
        } else if let task = task as? ManagedObject {
            task.save()
        } else {
            assertionFailure("cannot save task value")
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
