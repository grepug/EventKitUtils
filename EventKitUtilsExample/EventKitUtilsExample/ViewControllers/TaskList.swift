//
//  TaskList.swift
//  EventKitUtilsExample
//
//  Created by Kai on 2022/7/24.
//

import EventKit
import EventKitUtils

class TaskList: TaskListViewController {
    override func fetchTasks(forSegment segment: TaskListViewController.SegmentType) -> [TaskGroup] {
        let events = super.fetchTasks(forSegment: segment)
        
//        Mission.fetch(where: )
        return events
    }
    
    override func taskEditorViewController(task: TaskKind, eventStore: EKEventStore) -> TaskEditorViewController {
        TaskEditor(task: task, config: config, eventStore: eventStore)
    }
}
