//
//  TaskValue.swift
//  
//
//  Created by Kai on 2022/8/3.
//

import Foundation
import Collections

public struct TaskValue: TaskKind, Hashable {
    public var normalizedID: String
    public var normalizedTitle: String
    public var normalizedStartDate: Date?
    public var normalizedEndDate: Date?
    public var isAllDay: Bool
    public var isCompleted: Bool
    public var completedAt: Date?
    public var notes: String?
    public var keyResultId: String?
    public var linkedValue: Double?
    public var createdAt: Date?
    public var updatedAt: Date?
    public var isValueType: Bool = true
    
    public func toggleCompletion() {}
    
    public var kindIdentifier: TaskKindIdentifier
    public var repeatingCount: Int?
}

public extension Array where Element == TaskValue {
    #warning("need refactor, and improvement")
    func incompletedTasksAfter(_ date: Date) -> [TaskValue] {
        filter { task in
            guard !task.isCompleted else {
                return false
            }
            
            guard let endDate = task.normalizedEndDate else {
                return false
            }
                
            return endDate > date
        }
    }
    
    typealias TitleGrouped = OrderedDictionary<String, [TaskValue]>
    
    func titleGrouped(iterator: ((Element) -> Void)? = nil) -> TitleGrouped {
        var cache: TitleGrouped = .init()
        
        for task in self {
            iterator?(task)
            
            guard !task.isCompleted else {
                continue
            }
            
            if cache[task.normalizedTitle] == nil {
                cache[task.normalizedTitle] = []
            }
            
            cache[task.normalizedTitle]!.append(task)
        }
        
        return cache
    }
    
    func repeatingMerged(repeatingCount: (String) -> Int?) -> [TaskValue] {
        var taskValues: [TaskValue] = []
        var completedTaskValues: [TaskValue] = []
        let cache = titleGrouped { task in
            if task.isCompleted {
                completedTaskValues.append(task)
            }
        }
        
        for (_, tasks) in cache {
            if var first = tasks.first {
                first.repeatingCount = repeatingCount(first.normalizedTitle) ?? tasks.count
                
                taskValues.append(first)
            }
        }
        
        return taskValues + completedTaskValues
    }
}
