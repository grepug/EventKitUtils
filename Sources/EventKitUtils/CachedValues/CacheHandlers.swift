//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/9/9.
//

import Foundation
import StorageProvider
import CoreData

public protocol CacheHandlers {
    var cachedTaskKind: CachedTaskKind.Type { get }
    var persistentContainer: NSPersistentContainer { get }
    var completionDateNSExpression: NSExpression { get }
    var prefixNSExpression: NSExpression { get }
    var stateNSExpression: NSExpression { get }
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

extension CacheHandlers {
    private func statePredicates(_ states: [TaskKindState]) -> NSPredicate {
        let predicates = states.map {
            NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSComparisonPredicate.created(stateNSExpression, NSExpression(format: "%@", $0.rawValue as NSNumber), type: .equalTo),
                NSComparisonPredicate.created(prefixNSExpression, NSExpression(format: "0"), type: .equalTo),
            ])
        }
        
        return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
    }
    
    func fetchTaskValues(by type: EventKitUtils.FetchTasksType) async -> [EventKitUtils.TaskValue] {
        guard let runID = await currentRunID else {
            return []
        }
        
        let runIDPredicate = NSPredicate(format: "runID == %@", runID as CVarArg)
        let isCompletedPredicate: (Bool) -> NSPredicate = { isTrue in
            NSComparisonPredicate.created(completionDateNSExpression, NSExpression(format: "nil"), type: isTrue ? .equalTo : .notEqualTo)
        }
        var predicates = [runIDPredicate]
        
        switch type {
        case .segment(let segment):
            switch segment {
            case .completed:
                predicates.append(isCompletedPredicate(true))
            case .incompleted, .today:
                break
            }
            
            predicates.append(statePredicates(segment.displayStates))
            
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            
            let tasks = try! await cachedTaskKind.fetch(where: predicate) { objects in
                objects.map(\.value)
            }
            
            print("taskscount", tasks.count)
            
            return tasks
        case .repeatingInfo(let info):
            let predicate1 = NSPredicate(format: "title == %@ && keyResultID == %@",
                                         info.title as CVarArg,
                                         (info.keyResultID ?? "") as CVarArg)
            predicates.append(predicate1)
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            
            return try! await cachedTaskKind.fetch(where: predicate) { objects in
                objects.map(\.value)
            }
        default:
            return []
        }
    }
}

typealias CacheHandlersTaskValuesDict = [String: [TaskKindState: [TaskValue]]]

extension CacheHandlers {
    func createTasks(_ taskValues: CacheHandlersTaskValuesDict, withRunID runID: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let batchInsert = self.batchInsert(taskValues: taskValues, runID: runID)
                    try context.execute(batchInsert)
                    continuation.resume(returning: ())
                } catch {
                    print("error", error)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func clean(exceptRunID runID: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let request = cachedTaskKind.fetchRequest()
                    let predicate = NSPredicate(format: "runID != %@", runID as CVarArg)
                    request.predicate = predicate
                    
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                    // Execute the request.
                    let deleteResult = try context.execute(deleteRequest) as? NSBatchDeleteResult
                    
                    // Extract the IDs of the deleted managed objectss from the request's result.
                    if let objectIDs = deleteResult?.result as? [NSManagedObjectID] {
                        
                        // Merge the deletions into the app's managed object context.
                        NSManagedObjectContext.mergeChanges(
                            fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                            into: [context]
                        )
                    }
                    
                    continuation.resume(returning: ())
                } catch {
                    // Handle any thrown errors.
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private extension CacheHandlers {
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
