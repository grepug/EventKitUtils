//
//  File.swift
//  
//
//  Created by Kai on 2022/7/24.
//

import Foundation
import Combine

public enum FetchTasksType {
    case segment(TaskListViewController.SegmentType), title(String)
}

public typealias FetchTasksHandler = (FetchTasksType, @escaping ([TaskKind]) -> Void) -> Void

public struct TaskConfig {
    
    public init(eventBaseURL: URL, eventRequestRange: Range<Date>? = nil, fetchNonEventTasks: @escaping FetchTasksHandler, createNonEventTask: @escaping () -> TaskKind, taskById: @escaping (String) -> TaskKind?, testHasRepeatingTask: @escaping (TaskKind) -> Bool) {
        self.eventBaseURL = eventBaseURL
        self.createNonEventTask = createNonEventTask
        self.taskById = taskById
        self.testHasRepeatingTask = testHasRepeatingTask
        self.fetchNonEventTasks = fetchNonEventTasks
        
        let start = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let end = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        self.eventRequestRange = start..<end
    }
    
    let eventBaseURL: URL
    var eventRequestRange: Range<Date>
    var fetchNonEventTasks: FetchTasksHandler
    var createNonEventTask: () -> TaskKind
    var taskById: (String) -> TaskKind?
    var testHasRepeatingTask: (TaskKind) -> Bool
}
