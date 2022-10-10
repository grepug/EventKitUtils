//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/9/21.
//

import Foundation
import StorageProvider
import CoreData

typealias CacheHandlersTaskValuesDict = [TaskRepeatingInfo: [TaskKindState: [TaskValue]]]

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
        let taskRepeatingInfoArr = taskValues.map { $0.key }
        
        var i = 0
        var j = 0
        var k = 0
        
        let infoCount = taskRepeatingInfoArr.count
        let current = Date()
        var counts: [TaskRepeatingInfo: Int] = [:]
        
        return NSBatchInsertRequest(entity: cachedTaskKind.entity(),
                                    managedObjectHandler: { object in
            guard i < infoCount else {
                return true
            }
            
            guard var task = object as? CachedTaskKind else {
                return true
            }
            
            let info = taskRepeatingInfoArr[i]
            let tasksByState = taskValues[info]!
            let states = tasksByState.map { $0.key }
            
            let state = states[j]
            let curTaskValues = tasksByState[state]!
            
            let taskValue = curTaskValues[k]
            let taskValueCount = curTaskValues.count
            let repeatingCount = counts[info] ?? tasksByState.values.map { $0 }.reduce(into: 0) { $0 += $1.count }
            
            if counts[info] == nil {
                counts[info] = repeatingCount
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
    
    func statePredicates(_ states: [TaskKindState]) -> NSPredicate {
        let predicates = states.map { state in
            let statePredicate = state.predicate(completionExp: completionDateNSExpression,
                                                 abortionExp: abortionDateNSExpression,
                                                 stateExp: stateNSExpression)
            
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                statePredicate,
                NSComparisonPredicate.created(orderNSExpression, NSExpression(format: "0"), type: .equalTo),
            ])
        }
        
        return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
    }
    
    func fetchTaskCount(_ task: TaskValue) async -> Int {
        let predicate1 = NSComparisonPredicate.created(stateNSExpression,
                                                       NSExpression(format: "%@", task.state.rawValue as CVarArg),
                                                       type: .equalTo)
        let predicate2 = task.repeatingInfo.predicate()
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, predicate2])
        
        return try! await cachedTaskKind.fetchCount(where: predicate)!
    }
    
    func fetchTasksCounts(_ tasks: [TaskValue]) async -> CountsOfStateByRepeatingInfo {
        await withTaskGroup(of: (TaskValue, Int).self) { group in
            for task in tasks {
                group.addTask {
                    (task, await fetchTaskCount(task))
                }
            }
                
            var counts: CountsOfStateByRepeatingInfo = [:]
            
            for await (task, count) in group {
                assert(counts[task.repeatingInfoWithState] == nil)
                counts[task.repeatingInfoWithState] = count
            }
            
            return counts
        }
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
