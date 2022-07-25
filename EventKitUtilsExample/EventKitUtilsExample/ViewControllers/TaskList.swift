//
//  TaskList.swift
//  EventKitUtilsExample
//
//  Created by Kai on 2022/7/24.
//

import EventKit
import EventKitUtils
import StorageProvider
import Combine

class TaskList: TaskListViewController {
    override func taskEditorViewController(task: TaskKind, eventStore: EKEventStore) -> TaskEditorViewController {
        TaskEditor(task: task, config: config, eventStore: eventStore)
    }
    
    override func fetchNonEventTasksPublisher(for segment: TaskListViewController.SegmentType) -> AnyPublisher<[TaskKind], Error> {
        Mission.fetchPublisher(where: nil, sortedBy: nil, transform: { $0.map(\.value) })
            .eraseToAnyPublisher()
    }
}
