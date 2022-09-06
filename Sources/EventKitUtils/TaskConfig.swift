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
    case segment(FetchTasksSegmentType),
         repeatingInfo(TaskRepeatingInfo),
         taskID(String),
         recordValue(RecordValue)
}

public typealias FetchTasksHandler = (FetchTasksType, @escaping ([TaskValue]) -> Void) -> Void
public typealias PresentKeyResultSelectorHandler = (@escaping (String) -> Void) -> UIViewController?

public struct TaskConfig {
    
    public init(eventBaseURL: URL, appGroup: String? = nil, maxNonProLimit: @escaping () -> Int?, eventRequestRange: Range<Date>? = nil, fetchNonEventTasks: @escaping FetchTasksHandler, createNonEventTask: @escaping () -> TaskKind, taskById: @escaping (String) -> TaskKind?, taskCountWithRepeatingInfo: @escaping (TaskRepeatingInfo) -> Int, saveTask: @escaping (TaskValue) async -> Void, deleteTaskByID: @escaping (String) async -> Void, fetchKeyResultInfo: @escaping (String) async -> KeyResultInfo?) {
        self.eventBaseURL = eventBaseURL
        self.appGroup = appGroup
        self.maxNonProLimit = maxNonProLimit
        self.createNonEventTask = createNonEventTask
        self.taskById = taskById
        self.taskCountWithRepeatingInfo = taskCountWithRepeatingInfo
        self.fetchNonEventTasks = fetchNonEventTasks
        self.saveTask = saveTask
        self.deleteTaskByID = deleteTaskByID
        self.fetchKeyResultInfo = fetchKeyResultInfo
        
        let start = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let end = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        self.eventRequestRange = start..<end
    }
    
    public let eventBaseURL: URL
    public let appGroup: String?
    public var maxNonProLimit: () -> Int?
    public var eventRequestRange: Range<Date>
    public var fetchNonEventTasks: FetchTasksHandler
    public var createNonEventTask: () -> TaskKind
    public var taskById: (String) -> TaskKind?
    public var taskCountWithRepeatingInfo: (TaskRepeatingInfo) -> Int
    public var saveTask: (TaskValue) async -> Void
    public var deleteTaskByID: (String) async -> Void
    public var fetchKeyResultInfo: (String) async -> KeyResultInfo?
    public var makeKeyResultSelector: PresentKeyResultSelectorHandler?
    public var makeKeyResultDetail: ((String) -> UIViewController?)?
    public var presentNonProErrorAlert: ((() -> UIViewController) -> Void)?
    public var log: ((String) -> Void)?
    public var logError: ((Error) -> Void)?
    
    public var isPro: Bool {
        maxNonProLimit() == nil
    }
}

public struct KeyResultInfo: Hashable {
    public init(id: String, title: String, emojiImage: UIImage, goalTitle: String) {
        self.id = id
        self.title = title
        self.emojiImage = emojiImage
        self.goalTitle = goalTitle
    }
    
    public let id: String
    public let title: String
    public let emojiImage: UIImage
    public let goalTitle: String
}
