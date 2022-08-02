//
//  File.swift
//  
//
//  Created by Kai on 2022/7/24.
//

import Foundation
import Combine

public enum FetchTasksType: Hashable {
    case segment(TaskListViewController.SegmentType), title(String)
}

public typealias FetchTasksHandler = (FetchTasksType, @escaping ([TaskKind]) -> Void) -> Void
public typealias PresentKeyResultSelectorHandler = (@escaping (String) -> Void) -> Void

public struct TaskConfig {
    
    public init(eventBaseURL: URL, appGroup: String? = nil, eventRequestRange: Range<Date>? = nil, fetchNonEventTasks: @escaping FetchTasksHandler, createNonEventTask: @escaping () -> TaskKind, taskById: @escaping (String) -> TaskKind?, taskCountWithTitle: @escaping (TaskKind) -> Int, saveTask: @escaping (TaskKind) -> Void, deleteTask: @escaping (TaskKind) -> Void, presentKeyResultSelector: @escaping PresentKeyResultSelectorHandler) {
        self.eventBaseURL = eventBaseURL
        self.appGroup = appGroup
        self.createNonEventTask = createNonEventTask
        self.taskById = taskById
        self.taskCountWithTitle = taskCountWithTitle
        self.fetchNonEventTasks = fetchNonEventTasks
        self.saveTask = saveTask
        self.deleteTask = deleteTask
        self.presentKeyResultSelector = presentKeyResultSelector
        
        let start = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let end = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        self.eventRequestRange = start..<end
    }
    
    let eventBaseURL: URL
    let appGroup: String?
    var eventRequestRange: Range<Date>
    var fetchNonEventTasks: FetchTasksHandler
    var createNonEventTask: () -> TaskKind
    var taskById: (String) -> TaskKind?
    var taskCountWithTitle: (TaskKind) -> Int
    var saveTask: (TaskKind) -> Void
    var deleteTask: (TaskKind) -> Void
    var presentKeyResultSelector: PresentKeyResultSelectorHandler
}

extension TaskConfig {
    var userDefaults: UserDefaults {
        if let appGroup = appGroup,
        let userDefaults = UserDefaults(suiteName: appGroup) {
            return userDefaults
        }
        
        return UserDefaults.standard
    }
}
