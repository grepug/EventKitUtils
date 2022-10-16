//
//  EventManager+GroupTasks.swift
//  
//
//  Created by Kai Shao on 2022/9/15.
//

import Foundation
import EventKitUtils

typealias TasksByState = [TaskKindState?: [TaskValue]]

enum TaskListFilterState: Equatable, CaseIterable {
    case incompleted, aborted, completed
    
    var title: String {
        switch self {
        case .incompleted: return "filter_state_incompleted".loc
        case .completed: return "filter_state_completed".loc
        case .aborted: return "filter_state_aborted".loc
        }
    }
}

extension TaskListViewController {
    func groupTasks(_ tasks: [TaskValue], in segment: FetchTasksSegmentType, isRepeatingList: Bool) async -> TasksByState {
        await withCheckedContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(returning: [:])
                return
            }
            
            let segment = self.segment
            let isRepeatingList = self.isRepeatingList
            let filterState = self.selectedFilterTaskState
            
            DispatchQueue.global(qos: .userInitiated).async {
                let res = tasks.groupTasks(in: segment,
                                           isRepeatingList: isRepeatingList,
                                           filterState: filterState)
                continuation.resume(returning: res)
            }
        }
    }
}

fileprivate extension TaskValue {
    var repeatingListFilterState: TaskListFilterState {
        switch state {
        case .completed: return .completed
        case .aborted: return .aborted
        default: return .incompleted
        }
    }
}

fileprivate extension Array where Element == TaskValue {
    func groupTasks(in segment: FetchTasksSegmentType, isRepeatingList: Bool, filterState: TaskListFilterState?) -> TasksByState {
        var cache: TasksByState = [:]
        
        if isRepeatingList {
            guard !isEmpty else {
                return cache
            }
            
            if let filterState {
                cache[nil] = filter { $0.repeatingListFilterState == filterState }.sorted()
            } else {
                cache[nil] = sorted()
            }
            
            return cache
        }
        
        for task in self {
            if task.displayInSegment(segment) {
                let state = task.state
                
                if cache[state] == nil {
                    cache[state] = []
                }
                
                cache[state]!.append(task)
            }
        }
        
        var dict: TasksByState = [:]
        
        for (state, tasks) in cache {
            assert(tasks.allSatisfy { $0.state == state })
            
            dict[state] = tasks
                .sorted(in: state, of: segment)
                .repeatingMerged()
        }
        
        return dict
    }
}
