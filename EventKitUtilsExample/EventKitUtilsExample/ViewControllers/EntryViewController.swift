//
//  EntryViewController.swift
//  EventKitUtilsExample
//
//  Created by Kai on 2022/7/21.
//

import DiffableList
import UIKit
import EventKitUtils
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
                    let vc = TaskList(eventManager: .shared)
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
        .init(eventBaseURL: .init(string: "https://okr.vision/a")!) { type, handler in
            let context = StorageProvider.shared.persistentContainer.newBackgroundContext()
            
            context.perform {
                var predicate: NSPredicate? = nil
                
                switch type {
                case .segment:
                    break
                case .title(let title):
                    predicate = NSPredicate(format: "title = %@", title as CVarArg)
                }
                
                let missions = Mission.fetch(where: predicate, context: context)
                handler(missions)
            }
        } createNonEventTask: {
            let mission = Mission.initWithViewContext()
            
            return mission
        } taskById: { id in
            guard let uuid = UUID(uuidString: id) else {
                return nil
            }
            
            return Mission.fetch(byId: uuid)
        } taskCountWithTitle: { task in
            Mission.fetchCount(where: NSPredicate(format: "title = %@", task.normalizedTitle as CVarArg))
        } saveTask: { task in
            guard let mission = task as? Mission else {
                return
            }
            
            mission.save()
        } deleteTask: { task in
            guard let mission = task as? Mission else {
                return
            }
            
            mission.delete()
        } presentKeyResultSelector: { completion in
            
        }
    }
    
    static let shared = EventManager(config: EventManager.taskConfig)
}
