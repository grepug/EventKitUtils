//
//  File.swift
//  
//
//  Created by Kai on 2022/7/21.
//

import Foundation

public enum TaskKindState: Int, CaseIterable {
    case overdued, today, afterToday, unscheduled
    
    public var title: String {
        switch self {
        case .overdued: return "v3_task_state_overdued".loc
        case .today: return "v3_task_state_today".loc
        case .afterToday: return "v3_task_state_after_today".loc
        case .unscheduled: return "v3_task_state_unscheduled".loc
        }
    }
}

