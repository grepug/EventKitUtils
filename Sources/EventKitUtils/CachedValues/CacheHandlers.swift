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
}

extension CacheHandlers {
    func currentRunID() async -> String? {
        let context = cachedTaskKind.newBackgroundContext()
        
        return try? await cachedTaskKind.fetch(where: nil, sortedBy: [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ], fetchLimit: 1, context: context).first?.normalizedRunID
    }
    
    func fetchTaskValues(by type: EventKitUtils.FetchTasksType, firstOnly: Bool) async -> [EventKitUtils.TaskValue] {
        guard let runID = await currentRunID() else {
            return []
        }
        
        let runIDPredicate = NSPredicate(format: "runID == %@", runID as CVarArg)
        let firstOnlyPredicate = firstOnly ? NSPredicate(format: "isFirst == %@", firstOnly as NSNumber) : nil
        
        switch type {
        case .segment:
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [runIDPredicate, firstOnlyPredicate].compactMap { $0 })
            let context = cachedTaskKind.newBackgroundContext()
            
            return await context.performAsync {
                let request = cachedTaskKind.fetchRequest()
                request.predicate = predicate
                    
                let tasks = try! context.fetch(request) as! [CachedTaskKind]
                let taskValues = tasks.map(\.value)

                print("taskvalues", taskValues.count, runID)
                
                return taskValues
            }
        case .repeatingInfo(let info):
            let predicate1 = NSPredicate(format: "title == %@ && keyResultID == %@",
                                         info.title as CVarArg,
                                         (info.keyResultID ?? "") as CVarArg)
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, runIDPredicate].compactMap { $0 })
            
            let context = cachedTaskKind.newBackgroundContext()
            
            return await context.performAsync {
                let request = cachedTaskKind.fetchRequest()
                request.predicate = predicate
                    
                let tasks = try! context.fetch(request) as! [CachedTaskKind]
                let taskValues = tasks.map(\.value)
                
                return taskValues
            }
        default:
            return []
        }
    }
}

extension CacheHandlers {
    private func batchInsert(taskValues: [TaskValue], runID: String) -> NSBatchInsertRequest {
        let count = taskValues.count
        var index = 0
        let current = Date()
        
        return NSBatchInsertRequest(entity: cachedTaskKind.entity(),
                                    managedObjectHandler: { object in
            guard index < count else {
                return true
            }
            
            guard var task = object as? CachedTaskKind else {
                return true
            }
            
            task.assignFromTaskKind(taskValues[index])
            task.normalizedRunID = runID
            task.createdAt = current
            task.updatedAt = current
            
            index += 1
            
            return false
        })
    }
    
    func createTasks(_ taskValues: [TaskValue], withRunID runID: String) async throws {
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

    func clean() async throws {
        try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: cachedTaskKind.fetchRequest())
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

extension NSManagedObjectContext {
    func perform<T>(action: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            self.perform {
                do {
                    let result = try action()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func performAsync<T>(_ action: @escaping () -> T) async -> T {
        await withCheckedContinuation { continuation in
            self.perform {
                let result = action()
                continuation.resume(returning: result)
            }
        }
    }
}
