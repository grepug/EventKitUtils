//
//  FetchedTaskResult.swift
//  
//
//  Created by Kai Shao on 2022/10/11.
//

import Foundation
import OrderedCollections

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
    
    /// Use for merge non event tasks with event tasks.
    /// - Parameter fetchedResult: the ``FetchedTaskResult`` to merge with
    /// - Parameter deduplicatingWithRepeatingInfo: if should duplicating with repeating info, which only happens in fetching tasks for TaskListViewController
    /// - Returns: the merged ``FetchedTaskResult``
    func merged(with fetchedResult: FetchedTaskResult, mergingByRepeatingInfoWithState merging: Bool) -> FetchedTaskResult {
        if !merging {
            return .init(tasks: tasks + fetchedResult.tasks,
                         countsOfStateByRepeatingInfo: [:])
        }
        
        // Merge counts by adding the counts of the same repeatingInfo.
        let counts = fetchedResult.countsOfStateByRepeatingInfo.merging(countsOfStateByRepeatingInfo) { $0 + $1 }
        let tasks = tasks.merged(with: fetchedResult.tasks)

        return .init(tasks: tasks, countsOfStateByRepeatingInfo: counts)
    }
}

public extension Array where Element == TaskValue {
    var repeatingInfoWithStateSet: OrderedSet<TaskRepeatingInfo> {
        OrderedSet(map(\.repeatingInfoWithState))
    }
    
    var taskByRepeatingInfo: [TaskRepeatingInfo: TaskValue] {
        reduce(into: [:]) { partialResult, task in
            assert(partialResult[task.repeatingInfoWithState] == nil)
            partialResult[task.repeatingInfoWithState] = task
        }
    }
    
    func merged(with tasks: [TaskValue]) -> [TaskValue] {
        // Union of both repeatingInfo set
        let repeatingInfoSet = repeatingInfoWithStateSet.union(tasks.repeatingInfoWithStateSet)
        
        let taskByRepeatingInfo = taskByRepeatingInfo
        let taskByRepeatingInfo2 = tasks.taskByRepeatingInfo
        
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
        
        return tasks
    }
    
    /// Merge an array of ``TaskValue`` by its ``TaskRepeatingInfo`` without ``TaskKindState``
    ///
    /// Use for KeyResultDetailViewController to display the list of tasks linked to this key result where the repeating tasks should be merged without grouping with their ``TaskKindState``s.
    /// - Returns: a new array of ``TaskValue``
    func mergedByRepeatingInfo() -> [TaskValue] {
        let repeatingInfo = OrderedSet(map(\.repeatingInfo))
        let taskByRepeatingInfo: [TaskRepeatingInfo: TaskValue] = reduce(into: [:]) { partialResult, task in
            if partialResult[task.repeatingInfo] == nil {
                partialResult[task.repeatingInfo] = task
            }
        }
        
        return repeatingInfo.map { info in
            taskByRepeatingInfo[info]!
        }
    }
}
