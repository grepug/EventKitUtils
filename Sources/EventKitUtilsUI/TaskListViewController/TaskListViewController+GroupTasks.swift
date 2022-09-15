//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/9/15.
//

import Foundation
import EventKitUtils

typealias TaskGroupsByState = [TaskKindState?: [TaskValue]]
typealias TasksByState = [TaskKindState?: [TaskValue]]

extension TaskListViewController {
    
}

extension EventManager {
    func groupTasks(_ tasks: [TaskValue], in segment: FetchTasksSegmentType, isRepeatingList: Bool) async -> TaskGroupsByState {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let dict = self.groupTasks(tasks, in: segment, isRepeatingList: isRepeatingList)
                continuation.resume(returning: dict)
            }
        }
    }
    
    private func addToCache(_ state: TaskKindState?, _ task: TaskValue, in cache: inout TasksByState) {
        if cache[state] == nil {
            cache[state] = []
        }
        
        cache[state]!.append(task)
    }
    
    private func groupTasks(_ tasks: [TaskValue], in segment: FetchTasksSegmentType, isRepeatingList: Bool) -> TaskGroupsByState {
        var cache: TasksByState = [:]
        
        if isRepeatingList {
            cache[nil] = tasks.sorted()
            
            return cache
        }
        
        if segment == .completed {
            cache[nil] = tasks.filter { $0.isCompleted }
        } else {
            for task in tasks {
                if task.displayInSegment(segment) {
                    addToCache(task.state, task, in: &cache)
                }
            }
        }
        
        var dict: TaskGroupsByState = [:]
        let countsOfTitleGrouped = tasks.countsOfRepeatingGrouped
        
        for (state, tasks) in cache {
            dict[state] = tasks
                .sorted(in: state, of: segment)
                .repeatingMerged(withCountsOfTitleGrouped: countsOfTitleGrouped)
        }
        
        return dict
    }
}
