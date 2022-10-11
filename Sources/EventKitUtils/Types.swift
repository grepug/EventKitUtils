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
    case segment(FetchTasksSegmentType, keyResultID: String?),
         repeatingInfo(TaskRepeatingInfo),
         taskID(String),
         recordValue(RecordValue),
         keyResultDetailVC(String)
    
    var shouldMergeTasks: Bool {
        switch self {
        case .segment, .keyResultDetailVC: return true
        default: return false
        }
    }
    
    var shouldIncludeCounts: Bool {
        switch self {
        case .segment, .keyResultDetailVC: return true
        default: return false
        }
    }
}

public typealias CountsOfStateByRepeatingInfo = [TaskRepeatingInfo: Int]

public extension Dictionary where Key == TaskRepeatingInfo, Value == Int {
    func completedCountMerged(of task: TaskValue) -> Int {
        let incompletedCount = reduce(into: 0) { partialResult, pair in
            let info = pair.key
            let count = pair.value
            
            guard task.repeatingInfo == info.stateRemoved else {
                return
            }
            
            guard let state = info.state, state.isIncompleted else {
                return
            }
            
            partialResult += count
        }
        
        return Swift.max(task.repeatingCount - incompletedCount, 0)
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
