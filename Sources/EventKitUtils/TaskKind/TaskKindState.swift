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
         aborted, // 4
         completed // 5
    
    public var title: String {
        switch self {
        case .overdued: return "v3_task_state_overdued".loc
        case .today: return "v3_task_state_today".loc
        case .afterToday: return "v3_task_state_after_today".loc
        case .unscheduled: return "v3_task_state_unscheduled".loc
        case .completed: return "completed".loc
        case .aborted: return "abandoned".loc
        }
    }
    
    public func isInSegment(_ segment: FetchTasksSegmentType) -> Bool {
        segment.displayStates.contains(self)
    }
    
    public var isIncompleted: Bool {
        switch self {
        case .overdued, .afterToday, .today: return true
        case .completed, .aborted, .unscheduled: return false
        }
    }
    
    static func completedPredicate(stateNSExpression: NSExpression) -> NSPredicate {
        TaskKindState.allCases
            .filter { $0 == .completed }
            .map { state in
                NSComparisonPredicate.created(stateNSExpression,
                                              NSExpression(format: "\(state.rawValue)"),
                                              type: .equalTo)
            }
            .partialSatisfied
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
