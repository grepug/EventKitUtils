//
//  TaskWrapper.swift
//  
//
//  Created by Kai on 2022/7/25.
//

import Foundation

@dynamicMemberLookup
struct TaskWrapper<T: TaskKind> {
    var task: T
    var isRecurrence: Bool = false
    var futureTasks: [T]
    
    subscript<K>(dynamicMember keyPath: WritableKeyPath<T, K>) -> K {
        get { task[keyPath: keyPath] }
        set { task[keyPath: keyPath] = newValue }
    }
    
    var recurrenceCount: Int {
        futureTasks.count + 1
    }
}
