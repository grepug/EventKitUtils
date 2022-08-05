//
//  File.swift
//  
//
//  Created by Kai on 2022/7/24.
//

import Foundation
import Combine
import UIKit

public enum FetchTasksSegmentType: Int, CaseIterable {
    case today, incompleted, completed
    
    public var text: String {
        switch self {
        case .today: return "v3_task_list_segment_today".loc
        case .incompleted: return "v3_task_list_segment_incompleted".loc
        case .completed: return "v3_task_list_segment_completed".loc
        }
    }
}

public enum FetchTasksType: Hashable {
    case segment(FetchTasksSegmentType), title(String)
}

public typealias FetchTasksHandler = (FetchTasksType, @escaping ([TaskKind]) -> Void) -> Void
public typealias PresentKeyResultSelectorHandler = (@escaping (String) -> Void) -> UIViewController?

public struct TaskConfig {
    
    public init(eventBaseURL: URL, appGroup: String? = nil, eventRequestRange: Range<Date>? = nil, fetchNonEventTasks: @escaping FetchTasksHandler, createNonEventTask: @escaping () -> TaskKind, taskById: @escaping (String) -> TaskKind?, taskCountWithTitle: @escaping (TaskKind) -> Int, saveTask: @escaping (TaskKind) -> Void, deleteTask: @escaping (TaskKind) -> Void) {
        self.eventBaseURL = eventBaseURL
        self.appGroup = appGroup
        self.createNonEventTask = createNonEventTask
        self.taskById = taskById
        self.taskCountWithTitle = taskCountWithTitle
        self.fetchNonEventTasks = fetchNonEventTasks
        self.saveTask = saveTask
        self.deleteTask = deleteTask
        
        let start = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let end = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        self.eventRequestRange = start..<end
    }
    
    public let eventBaseURL: URL
    public let appGroup: String?
    public var eventRequestRange: Range<Date>
    public var fetchNonEventTasks: FetchTasksHandler
    public var createNonEventTask: () -> TaskKind
    public var taskById: (String) -> TaskKind?
    public var taskCountWithTitle: (TaskKind) -> Int
    public var saveTask: (TaskKind) -> Void
    public var deleteTask: (TaskKind) -> Void
    public var makeKeyResultSelector: PresentKeyResultSelectorHandler?
    public var makeKeyResultDetail: ((String) -> UIViewController?)?
}
