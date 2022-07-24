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
    
    func filtered(_ tasks: [TaskKind], includingCompleted: Bool = true) -> [TaskKind] {
        let current = Date()
        
        return tasks.filter { task in
            if !includingCompleted && task.isCompleted {
                return false
            }
            
            if task.isDateEnabled, let date = task.normalizedEndDate {
                switch self {
                case .overdued:
                    if date.startOfDay < current.startOfDay {
                        return true
                    }
                case .today:
                    if date.startOfDay >= current.startOfDay &&
                        date.startOfDay < current.tomorrow.startOfDay {
                        return true
                    }
                case .afterToday:
                    if let date = task.normalizedEndDate {
                        if date.startOfDay >= current.tomorrow.startOfDay {
                            return true
                        }
                    }
                case .unscheduled:
                    return false
                }
            }
            
            if self == .unscheduled {
                return true
            }
            
            return false
        }
    }
}

