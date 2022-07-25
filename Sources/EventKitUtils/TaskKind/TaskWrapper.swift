//
//  TaskWrapper.swift
//  
//
//  Created by Kai on 2022/7/25.
//

import Foundation

@dynamicMemberLookup
public struct TaskWrapper {
    var first: TaskKind
    var isRecurrence: Bool = false
    var futureTasks: [TaskKind]
    
    subscript<K>(dynamicMember keyPath: WritableKeyPath<TaskKind, K>) -> K {
        get { first[keyPath: keyPath] }
        set { first[keyPath: keyPath] = newValue }
    }
    
    var recurrenceCount: Int {
        futureTasks.count + 1
    }
}
