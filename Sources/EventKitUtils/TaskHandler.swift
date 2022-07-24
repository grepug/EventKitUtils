//
//  TaskHandler.swift
//  
//
//  Created by Kai on 2022/7/24.
//

import EventKit

protocol TaskHandler {
    var eventStore: EKEventStore { get }
}

extension TaskHandler {
    func saveTask(_ task: TaskKind) {
        if let event = task as? EKEvent {
            try! eventStore.save(event, span: .thisEvent, commit: true)
        }
        
    }
}
