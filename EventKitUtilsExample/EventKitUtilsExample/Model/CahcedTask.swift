//
//  CahcedTask.swift
//  EventKitUtilsExample
//
//  Created by Kai Shao on 2022/9/10.
//

import StorageProvider
import EventKitUtils

extension CachedTask: SimpleManagedObject {
    
}

extension CachedTaskRun: SimpleManagedObject {
    var sortedTasks: [CachedTask] {
        guard let tasks = tasks as? Set<CachedTask> else {
            return []
        }
        
        return tasks.map { $0 }
    }
}

extension CachedTask {
    var value: TaskValue {
        .init(normalizedID: idString!, normalizedTitle: title!, normalizedStartDate: startDate, normalizedEndDate: endDate, normalizedIsAllDay: isAllDay, isCompleted: completionDate != nil, completedAt: completionDate, notes: notes ?? "", keyResultId: keyResultID, linkedValue: linkedRecordValue)
    }
    
    func assignedFromTaskValue(_ taskValue: TaskValue) {
        idString = taskValue.normalizedID
        title = taskValue.normalizedTitle
        startDate = taskValue.normalizedStartDate
        endDate = taskValue.normalizedEndDate
        isAllDay = taskValue.normalizedIsAllDay
        completionDate = taskValue.completedAt
        notes = taskValue.notes
        keyResultID = taskValue.keyResultId
        linkedRecordValue = taskValue.linkedValue ?? 0
    }
}
