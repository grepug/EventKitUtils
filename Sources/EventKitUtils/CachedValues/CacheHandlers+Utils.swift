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
    
    var firstOrderPredicate: NSPredicate {
        NSComparisonPredicate.created(orderNSExpression, NSExpression(format: "0"), type: .equalTo)
    }
    
    func statePredicate(_ state: TaskKindState) -> NSPredicate {
        NSComparisonPredicate.created(stateNSExpression, NSExpression(format: "\(state.rawValue)"), type: .equalTo)
    }
    
    func statePredicates(_ states: [TaskKindState]) -> NSPredicate {
        let predicates = states.map { state in
            NSCompoundPredicate(andPredicateWithSubpredicates: [
                statePredicate(state),
                firstOrderPredicate
            ])
        }
        
        return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
    }
    
    private func fetchIncompletedTaskCount(_ task: TaskValue) async -> Int {
        let predicate1 = TaskKindState.completedPredicate(stateNSExpression: stateNSExpression)
        let predicate2 = task.repeatingInfo.predicate()
        
        return try! await cachedTaskKind.fetchCount(where: [predicate1, predicate2].allSatisfied)!
    }
    
    func fetchTasksCounts(_ tasks: [TaskValue]) async -> CountsOfCompletedTasksByRepeatingInfo {
        await withTaskGroup(of: (TaskValue, Int).self) { group in
            for task in tasks {
                group.addTask {
                    (task, await fetchIncompletedTaskCount(task))
                }
            }
                
            var counts: CountsOfCompletedTasksByRepeatingInfo = [:]
            
            for await (task, count) in group {
//                assert(counts[task.repeatingInfo] == nil)
                counts[task.repeatingInfo] = count
            }
            
            return counts
        }
    }
    
    func fetchTasksCount(withKeyResultID keyResultID: String) async -> Int {
        try! await cachedTaskKind.fetchCount(where: .keyResultID(keyResultID)) ?? 0
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
