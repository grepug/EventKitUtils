//
//  EntryViewController.swift
//  EventKitUtilsExample
//
//  Created by Kai on 2022/7/21.
//

import DiffableList
import UIKit
import EventKitUtils

class EntryViewController: DiffableListViewController {
    var taskConfig: TaskConfig {
        .init(eventBaseURL: .init(string: "https://okr.vision/a")!) {
            let mission = Mission.initWithViewContext()
            
            return mission
        }
    }
    
    override var list: DLList {
        DLList { [unowned self] in
            DLSection {
                DLCell {
                    DLText("TaskListViewController")
                }
                .tag("taskList")
                .accessories([.disclosureIndicator()])
                .onTapAndDeselect { [unowned self] _ in
                    let vc = TaskList(config: taskConfig)
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
