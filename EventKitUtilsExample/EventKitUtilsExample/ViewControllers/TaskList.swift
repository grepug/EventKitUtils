//
//  TaskList.swift
//  EventKitUtilsExample
//
//  Created by Kai on 2022/7/24.
//

import EventKit
import EventKitUtils

class TaskList: TaskListViewController {
    override func fetchTasks(forSegment segment: TaskListViewController.SegmentType) -> [TaskKind] {
        let events = super.fetchTasks(forSegment: segment)
        
        return events
    }
    
    override func taskEditorViewController(task: TaskKind, eventStore: EKEventStore) -> TaskEditorViewController {
        TaskEditor(task: task, eventStore: eventStore)
    }
}
