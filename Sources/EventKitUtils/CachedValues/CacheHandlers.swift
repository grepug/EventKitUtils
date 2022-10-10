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
    var abortionDateNSExpression: NSExpression { get }
    var orderNSExpression: NSExpression { get }
    var stateNSExpression: NSExpression { get }
}

extension CacheHandlers {
    func fetchTaskValues(by type: EventKitUtils.FetchTasksType, includingCounts: Bool = false) async -> FetchedTaskResult? {
        guard let runID = await currentRunID else {
            return nil
        }
        
        let runIDPredicate = NSPredicate(format: "runID == %@", runID as CVarArg)
        var predicates = [runIDPredicate]
        let sortDescriptors: [NSSortDescriptor] = [.init(key: "startDate", ascending: true)]
        
        switch type {
        case .segment(let segment):
            let statePredicate = statePredicates(segment.displayStates)
            predicates.append(statePredicate)
            
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            
            let tasks = try! await cachedTaskKind.fetch(where: predicate, sortedBy: sortDescriptors) { objects in
                objects.map(\.value)
            }
            
            let counts = includingCounts ? await fetchTasksCounts(tasks) : [:]
            
            assert(tasks.allSatisfy { segment.displayStates.contains($0.state) })
            
            return .init(tasks: tasks, countsOfStateByRepeatingInfo: counts)
        case .repeatingInfo(let info):
            predicates.append(info.predicate())
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            
            let tasks = try! await cachedTaskKind.fetch(where: predicate,
                                                        sortedBy: sortDescriptors) { objects in
                objects.map(\.value)
            }
            
            return .init(tasks: tasks, countsOfStateByRepeatingInfo: [:])
        default:
            return nil
        }
    }
}

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

    func cleanup(exceptRunID runID: String) async throws {
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
