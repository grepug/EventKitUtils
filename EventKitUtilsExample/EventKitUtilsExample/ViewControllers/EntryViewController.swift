//
//  EntryViewController.swift
//  EventKitUtilsExample
//
//  Created by Kai on 2022/7/21.
//

import DiffableList
import UIKit
import UIKitUtils
import EventKitUtils
import EventKitUtilsUI
import StorageProvider
import CoreData

class EntryViewController: DiffableListViewController {
    override var list: DLList {
        DLList { [unowned self] in
            DLSection {
                DLCell {
                    DLText("TaskListViewController")
                }
                .tag("taskList")
                .accessories([.disclosureIndicator()])
                .onTapAndDeselect { [unowned self] _ in
                    let vc = TaskListViewController(eventManager: .shared)
                    push(vc)
                }
                
                DLCell {
                    DLText("EventSettings")
                }
                .tag("eventSettings")
                .accessories([.disclosureIndicator()])
                .onTapAndDeselect { [unowned self] _ in
                    let vc = EventSettingsViewController(eventManager: .shared)
                    push(vc)
                }
                
                DLCell {
                    DLText("TaskSummaryCard")
                }
                .tag("taskSummaryCard")
                .accessories([.disclosureIndicator()])
                .onTapAndDeselect { [unowned self] _ in
                    let vc = TaskSummaryCardList()
                    push(vc)
                }
                
            }
            .tag("0")
            
            DLSection {
                DLCell {
                    DLText("Test")
                }
                .tag("test")
                .onTapAndDeselect { [weak self] _ in
                    self?.push(TestingViewController())
                }
            }
            .tag("1")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Entry"
        navigationController?.navigationBar.prefersLargeTitles = true
        setTopPadding()
        
        reload()
    }
}


extension EventManager {
    private static var taskConfig: TaskConfig {
        .init(eventBaseURL: .init(string: "https://okr.vision/a")!) {
            nil
        } fetchNonEventTasks: { type, handler in
            let context = StorageProvider.shared.persistentContainer.newBackgroundContext()
            
            context.perform {
                var predicate: NSPredicate? = nil
                
                switch type {
                case .segment, .recordValue:
                    break
                case .repeatingInfo(let info):
                    break
                    //                    predicate = NSPredicate(format: "title = %@", title as CVarArg)
                case .taskID(_):
                    break
                }
                
                let missions = Mission.fetch(where: predicate, context: context)
                handler(missions.map(\.value))
            }
            
        } createNonEventTask: {
            let mission = Mission.initWithViewContext()
            
            return mission
        } taskById: { id in
            guard let uuid = UUID(uuidString: id) else {
                return nil
            }
            
            return Mission.fetch(byId: uuid)
        } taskCountWithRepeatingInfo: { task in
            0
        } saveTask: { taskValue in
            
        } deleteTaskByID: { id in
            
        } fetchKeyResultInfo: { _ in
            nil
        }
    }
    
    static let shared = EventManager(config: EventManager.taskConfig,
                                     cacheHandlers: MyCacheHandlers())
}

extension EventManager {
    struct MyCacheHandlers: CacheHandlers {
        let context = StorageProvider.shared.persistentContainer.newBackgroundContext()
        
        func currentRunID() async -> String? {
            await context.perform {
                CachedTask.fetch(sortedBy: [
                    NSSortDescriptor(key: "createdAt", ascending: false)
                ], fetchLimit: 1, context: context).first?.runID
            }
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
                let taskValues = CachedTask.fetch(where: predicate)
                    .map(\.value)
                
                print("taskvalues", taskValues.count, runID, taskValues.map(\.normalizedTitle))
                
                return taskValues
            case .repeatingInfo(let info):
                let predicate1 = NSPredicate(format: "title == %@ && keyResultID == %@",
                                             info.title as CVarArg,
                                             (info.keyResultID ?? "") as CVarArg)
                let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, runIDPredicate].compactMap { $0 })
                let taskValues = CachedTask.fetch(where: predicate)
                    .map(\.value)
                    .sorted()
                
                print(taskValues.count, info)
                
                return taskValues
            default:
                return []
            }
        }
        
        func fetchRecordValuesByKeyResultID(_ id: String) async -> [EventKitUtils.RecordValue] {
            []
        }
        
        func createRun(id: String, at date: Date) async {
            await context.perform {
                let run = CachedTaskRun.initWithViewContext(context)
                run.id = UUID(uuidString: id)!
                run.state = Int16(CacheHandlersRunState.inProgress.rawValue)
                try! context.save()
            }
        }
        
        var currentInProgressRunID: String? {
            get {
                let predicate = NSPredicate(format: "state == %@", CacheHandlersRunState.inProgress.rawValue as NSNumber)
                
                return CachedTaskRun.fetch(where: predicate, sortedBy: [
                    NSSortDescriptor(key: "createdAt", ascending: false)
                ], fetchLimit: 1, context: context).first?.id?.uuidString
            }
        }
        
        func createTask(_ taskValue: TaskValue, isFirst: Bool, withRunID runID: String) async {
            await context.perform {
                let task = CachedTask.initWithViewContext(context)
                task.assignedFromTaskValue(taskValue)
                task.isFirst = isFirst
                task.run = CachedTaskRun.fetch(byId: UUID(uuidString: runID)!,
                                               context: context)!
                try! context.save()
            }
        }
        
        func batchInsert(taskValues: [TaskValue], runID: String) -> NSBatchInsertRequest {
            let count = taskValues.count
            var index = 0
            let current = Date()
            
            return NSBatchInsertRequest(entity: .entity(forEntityName: "CachedTask", in: context)!,
                                        managedObjectHandler: { object in
                guard index < count else {
                    return true
                }
                
                guard let task = object as? CachedTask else {
                    return true
                }
                
                task.assignedFromTaskValue(taskValues[index])
                task.runID = runID
                task.createdAt = current
                task.updatedAt = current
                
                index += 1
                
                return false
            })
        }
        
        func createTasks(_ taskValues: [TaskValue], withRunID runID: String) async {
            await StorageProvider.shared.persistentContainer.performBackgroundTask { context in
                do {
                    let batchInsert = self.batchInsert(taskValues: taskValues, runID: runID)
                    try context.execute(batchInsert)
                } catch {
                    print("error", error)
                }
            }
        }
        
        func setRunState(_ state: CacheHandlersRunState, withID id: String) async {
            return await context.perform {
                let run = CachedTaskRun.fetch(byId: UUID(uuidString: id)!,
                                              context: context)!
                run.state = Int16(state.rawValue)
                try! context.save()
            }
        }
        
        func clean() async {
            
        }
    }
}
