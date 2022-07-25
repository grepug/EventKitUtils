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
    public init(tasks: [TaskKind], isRecurrence: Bool = false) {
        guard !tasks.isEmpty else {
            fatalError("task wrapper tasks cannot be empty")
        }
        
        self.tasks = tasks
        self.isRecurrence = isRecurrence
    }
    
    var tasks: [TaskKind]
    var isRecurrence: Bool = false
    
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

public extension Array where Element: TaskKind {
    func makeTaskGroups() -> [TaskGroup] {
        var wrappers: [TaskGroup] = []
        var cache: OrderedDictionary<String, [TaskKind]> = .init()
        
        for task in self {
            if cache[task.normalizedTitle] == nil {
                cache[task.normalizedTitle] = []
            }
            
            cache[task.normalizedTitle]!.append(task)
        }
        
        for (_, tasks) in cache {
            wrappers.append(
                .init(tasks: tasks, isRecurrence: false)
            )
        }
        
        return wrappers
    }
}
