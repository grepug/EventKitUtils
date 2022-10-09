//
//  File.swift
//  
//
//  Created by Kai on 2022/7/21.
//

import Foundation

public enum TaskKindState: Int, CaseIterable {
    case overdued, // 0
         today, // 1
         afterToday, // 2
         unscheduled, // 3
         completed, // 4
         aborted // 5
    
    public var title: String {
        switch self {
        case .overdued: return "v3_task_state_overdued".loc
        case .today: return "v3_task_state_today".loc
        case .afterToday: return "v3_task_state_after_today".loc
        case .unscheduled: return "v3_task_state_unscheduled".loc
        case .completed: return "已完成".loc
        case .aborted: return "已放弃".loc
        }
    }
    
    public func isInSegment(_ segment: FetchTasksSegmentType) -> Bool {
        segment.displayStates.contains(self)
    }
    
    public func predicate(completionExp: NSExpression, abortionExp: NSExpression, stateExp: NSExpression) -> NSPredicate {
        switch self {
        case .completed:
            return NSComparisonPredicate.created(completionExp, NSExpression(format: "%@", NSNull()), type: .notEqualTo)
        case .aborted:
            return NSComparisonPredicate.created(abortionExp, NSExpression(format: "%@", NSNull()), type: .notEqualTo)
        default:
            return NSComparisonPredicate.created(stateExp, NSExpression(format: "%@", rawValue as NSNumber), type: .equalTo)
        }
    }
}

public extension TaskKindState {
    // is completed or aborted
    var isEnded: Bool {
        switch self {
        case .completed, .aborted: return true
        default: return false
        }
    }
}

public extension FetchTasksSegmentType {
    var displayStates: [TaskKindState] {
        switch self {
        case .today: return [.overdued, .today]
        case .incompleted: return [.overdued, .today, .afterToday, .unscheduled]
        case .completed: return [.completed, .aborted]
        }
    }
}
