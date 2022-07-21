//
//  TaskListViewController+Segment.swift
//  
//
//  Created by Kai on 2022/7/20.
//

import Foundation

public extension TaskListViewController {
    enum SegmentType: Int, CaseIterable {
        case today, incompleted, completed
        
        var text: String {
            switch self {
            case .today: return "v3_task_list_segment_today"
            case .incompleted: return "v3_task_list_segment_incompleted"
            case .completed: return "v3_task_list_segment_completed"
            }
        }
    }
}
