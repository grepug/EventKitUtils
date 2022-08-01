//
//  TaskList.swift
//  EventKitUtilsExample
//
//  Created by Kai on 2022/7/24.
//

import EventKit
import EventKitUtils
import StorageProvider

class TaskList: TaskListViewController {
    override func taskEditorViewController(task: TaskKind) -> TaskEditorViewController {
        TaskEditor(task: task, eventManager: .shared)
    }
    
    override func makeRepeatingListViewController(title: String) -> TaskListViewController? {
        TaskList(eventManager: .shared, fetchingTitle: title)
    }
}
