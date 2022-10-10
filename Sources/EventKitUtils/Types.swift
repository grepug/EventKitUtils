//
//  Types.swift
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
        case .completed: return "已结束".loc
        }
    }
}

public enum FetchTasksType: Hashable {
    case segment(FetchTasksSegmentType),
         repeatingInfo(TaskRepeatingInfo),
         taskID(String),
         recordValue(RecordValue)
}

public typealias CountsOfStateByRepeatingInfo = [TaskRepeatingInfo: Int]

public struct FetchedTaskResult {
    public init(tasks: [TaskValue], countsOfStateByRepeatingInfo: CountsOfStateByRepeatingInfo) {
        self.tasks = tasks
        self.countsOfStateByRepeatingInfo = countsOfStateByRepeatingInfo
    }
    
    init() {
        self.tasks = []
        self.countsOfStateByRepeatingInfo = [:]
    }
    
    public var tasks: [TaskValue]
    public let countsOfStateByRepeatingInfo: CountsOfStateByRepeatingInfo
    
    var repeatingInfoSet: Set<TaskRepeatingInfo> {
        Set(tasks.map(\.repeatingInfo))
    }
    
    var taskByRepeatingInfo: [TaskRepeatingInfo: TaskValue] {
        tasks.reduce(into: [:]) { partialResult, task in
            assert(partialResult[task.repeatingInfoWithState] == nil)
            partialResult[task.repeatingInfoWithState] = task
        }
    }
    
    /// Use for merge non event tasks with event tasks.
    /// - Parameter tasksInfo: ``FetchTasksInfo``
    /// - Returns: the merged ``FetchTasksInfo``
    func merged(with fetchedResult: FetchedTaskResult) -> FetchedTaskResult {
        // Merge counts by adding the counts of the same repeatingInfo.
        let counts = fetchedResult.countsOfStateByRepeatingInfo.merging(countsOfStateByRepeatingInfo) { $0 + $1 }
        
        // Union of both repeatingInfo set
        let repeatingInfoSet = repeatingInfoSet.union(fetchedResult.repeatingInfoSet)
        
        let taskByRepeatingInfo = taskByRepeatingInfo
        let taskByRepeatingInfo2 = fetchedResult.taskByRepeatingInfo
        
        let tasks = repeatingInfoSet.map { info in
            let task1 = taskByRepeatingInfo[info]
            let task2 = taskByRepeatingInfo2[info]
            
            if let task1, let task2 {
                return task1.merge(with: task2)
            }
            
            if let task1 {
                return task1
            }
            
            if let task2 {
                return task2
            }
            
            fatalError("not possible")
        }

        return .init(tasks: tasks, countsOfStateByRepeatingInfo: counts)
    }
}

public struct KeyResultInfo: Hashable {
    public init(id: String, title: String, emojiImage: UIImage, goalTitle: String, goalDateInterval: DateInterval) {
        self.id = id
        self.title = title
        self.emojiImage = emojiImage
        self.goalTitle = goalTitle
        self.goalDateInterval = goalDateInterval
    }
    
    public let id: String
    public let title: String
    public let emojiImage: UIImage
    public let goalTitle: String
    public let goalDateInterval: DateInterval
}
