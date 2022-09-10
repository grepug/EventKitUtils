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
                case .repeatingInfo(let info, _):
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
        func currentRunID() async -> String? {
            let predicate = NSPredicate(format: "state == %@", CacheHandlersRunState.completed.rawValue as CVarArg)
            
            return try? await CachedTaskRun.fetch(where: predicate, sortedBy: [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ], fetchLimit: 1).first?.id?.uuidString
        }
        
        func fetchTaskValues(by type: EventKitUtils.FetchTasksType) async -> [EventKitUtils.TaskValue] {
            guard let runID = await currentRunID() else {
                return []
            }
            
            switch type {
            case .segment:
                let predicate = NSPredicate(format: "run.id == %@ && isFirst == 1", runID as CVarArg)
                let taskValues = CachedTaskRun.fetch(where: predicate)
                    .map(\.sortedTasks)
                    .compactMap(\.first)
                    .map(\.value)
                    .sorted()
                
                return taskValues
            default:
                return []
            }
        }
        
        func fetchRecordValuesByKeyResultID(_ id: String) async -> [EventKitUtils.RecordValue] {
            []
        }
        
        func createRun(at date: Date) async -> String {
            let context = StorageProvider.shared.persistentContainer.newBackgroundContext()
            
            return await context.perform {
                let run = CachedTaskRun.initWithViewContext(context)
                try! context.save()
                
                return run.id!.uuidString
            }
        }
        
        func createTask(_ taskValue: TaskValue, isFirst: Bool, withRunID runID: String) async {
            let context = StorageProvider.shared.persistentContainer.newBackgroundContext()
            
            await context.perform {
                let task = CachedTask.initWithViewContext(context)
                task.assignedFromTaskValue(taskValue)
                task.isFirst = isFirst
                task.run = CachedTaskRun.fetch(byId: UUID(uuidString: runID)!,
                                               context: context)!
                try! context.save()
            }
        }
        
        func setRunState(_ state: CacheHandlersRunState, withID id: String) async {
            guard let run = try? await CachedTaskRun.fetch(byId: UUID(uuidString: id)!) else {
                return
            }
            
            run.state = Int16(state.rawValue)
            run.save()
        }
        
        func clean() async {
            
        }
    }
}
