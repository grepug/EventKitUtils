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
