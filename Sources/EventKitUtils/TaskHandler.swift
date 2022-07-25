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
}

extension TaskHandler {
    func saveTask(_ task: TaskKind) {
        if let event = task as? EKEvent {
            try! eventStore.save(event, span: .thisEvent, commit: true)
        } else if let task = task as? ManagedObject {
            task.save()
        }
    }
    
    func deleteTask(_ task: TaskKind) {
        if let event = task as? EKEvent {
             
        } else if let task = task as? ManagedObject {
            task.delete()
        }
    }
}
