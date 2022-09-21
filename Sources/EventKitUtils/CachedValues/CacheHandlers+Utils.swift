//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/9/21.
//

import Foundation
import StorageProvider
import CoreData

typealias CacheHandlersTaskValuesDict = [String: [TaskKindState: [TaskValue]]]

extension CacheHandlers {
    var currentRunID: String? {
        get async {
            try? await cachedTaskKind.fetch(where: nil, sortedBy: [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ], fetchLimit: 1) { objects in
                objects.first?.normalizedRunID
            }
        }
    }
    
    func batchInsert(taskValues: CacheHandlersTaskValuesDict, runID: String) -> NSBatchInsertRequest {
        let taskIDs = taskValues.map { $0.key }
        
        var i = 0
        var j = 0
        var k = 0
        
        let idCount = taskIDs.count
        let current = Date()
        var counts: [String: Int] = [:]
        
        return NSBatchInsertRequest(entity: cachedTaskKind.entity(),
                                    managedObjectHandler: { object in
            guard i < idCount else {
                return true
            }
            
            guard var task = object as? CachedTaskKind else {
                return true
            }
            
            let id = taskIDs[i]
            let tasksByState = taskValues[id]!
            let states = tasksByState.map { $0.key }
            
            let state = states[j]
            let curTaskValues = tasksByState[state]!
            
            let taskValue = curTaskValues[k]
            let taskValueCount = curTaskValues.count
            let repeatingCount = counts[id] ??
            tasksByState.values.map { $0 }.reduce(into: 0) { $0 += $1.count }
            
            if counts[id] == nil {
                counts[id] = repeatingCount
            }
            
            task.assignFromTaskKind(taskValue)
            task.order = k
            task.repeatingCount = repeatingCount
            task.state = taskValue.state
            
            task.normalizedRunID = runID
            task.createdAt = current
            task.updatedAt = current
            
            k += 1
            
            if k == taskValueCount {
                k = 0
                j += 1

                if j == states.count {
                    j = 0
                    i += 1
                }
            }
            
            return false
        })
    }
}

extension NSComparisonPredicate {
    static func created(_ exp1: NSExpression, _ exp2: NSExpression, type: NSComparisonPredicate.Operator) -> NSPredicate {
        NSComparisonPredicate(leftExpression: exp1,
                              rightExpression: exp2,
                              modifier: .direct,
                              type: type,
                              options: .normalized)
    }
}
