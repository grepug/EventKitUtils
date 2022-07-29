//
//  TaskGroup.swift
//  
//
//  Created by Kai on 2022/7/25.
//

import Foundation
import Collections

@dynamicMemberLookup
public struct TaskGroup {
    public init(tasks: [TaskKind]) {
        guard !tasks.isEmpty else {
            fatalError("task wrapper tasks cannot be empty")
        }
        
        self.tasks = tasks
    }
    
    var tasks: [TaskKind]
    
    var first: TaskKind {
        get { tasks[0] }
        set { tasks[0] = newValue }
    }
    
    var futureTasks: ArraySlice<TaskKind> {
        tasks.dropFirst()
    }
    
    var hasFutureTasks: Bool {
        !futureTasks.isEmpty
    }
    
    subscript<K>(dynamicMember keyPath: WritableKeyPath<TaskKind, K>) -> K {
        get { first[keyPath: keyPath] }
        set { first[keyPath: keyPath] = newValue }
    }
    
    var recurrenceCount: Int? {
        guard hasFutureTasks else {
            return nil
        }
        
        return futureTasks.count
    }
    
    var cellTag: String {
        first.cellTag +
        "\(recurrenceCount ?? 0)"
    }
}

extension TaskGroup {
    func incompletedTasksAfter(_ date: Date) -> [TaskKind] {
        tasks.filter { task in
            guard !task.isCompleted else {
                return false
            }
            
            guard let endDate = task.normalizedEndDate else {
                return false
            }
                
            return endDate > date
        }
    }
}

public extension Array where Element == TaskKind {
    func makeTaskGroups() -> [TaskGroup] {
        var groups: [TaskGroup] = []
        var completedGroups: [TaskGroup] = []
        var cache: OrderedDictionary<String, [TaskKind]> = .init()
        
        for task in self {
            if task.isCompleted {
                completedGroups.append(.init(tasks: [task]))
            } else {
                if cache[task.normalizedTitle] == nil {
                    cache[task.normalizedTitle] = []
                }
                
                cache[task.normalizedTitle]!.append(task)
            }
        }
        
        for (_, tasks) in cache {
            guard !tasks.isEmpty else {
                continue
            }
            
            groups.append(.init(tasks: tasks))
        }
        
        return groups + completedGroups
    }
}

extension Array where Element == TaskGroup {
    func merged() -> TaskGroup {
        let tasks = reduce(into: []) {
            $0 += $1.tasks
        }
        
        return .init(tasks: tasks)
    }
}
