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
    
    static let shared = EventManager(config: EventManager.taskConfig)
}
