//
//  TaskEditorViewController.swift
//  
//
//  Created by Kai on 2022/7/21.
//

import DiffableList
import UIKit
import SwiftUI

class TaskEditorViewController: DiffableListViewController {
    var task: TaskKind
    
    init(task: TaskKind) {
        self.task = task
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var list: DLList {
        DLList { [unowned self] in
            DLSection { [unowned self] in
                DLCell(using: .textField(text: self.task.normalizedTitle,
                                         placeholder: "v3_task_editor_title_ph".loc,
                                         editingDidEnd: { [unowned self] value in
                    task.normalizedTitle = value
                }))
                .tag(task.normalizedTitle)
            }
            .tag("title \(self.task.normalizedTitle)")
            
            DLSection {
                DLCell {
                    DLText("计划时间")
                }
                .tag("enable planDate \(self.task.isDateEnabled.description)")
                .accessories([.toggle(isOn: self.task.isDateEnabled, action: { [unowned self] isOn in
                    task.isDateEnabled = isOn
                    reload()
                })])
                
                DLCell {
                    DLText("全天")
                }
                .tag("is all day \(self.task.isAllDay.description)")
                .accessories([.toggle(isOn: self.task.isAllDay, action: { [unowned self] isOn in
                    task.isAllDay = isOn
                    reload()
                })])
                
                DLCell(using: .datePicker(labelText: "开始时间",
                                          date: self.task.normalizedStartDate ?? Date(),
                                          valueDidChange: { [unowned self] date in
                    task.normalizedStartDate = date
                }))
                .tag("startDate")
                
                DLCell(using: .datePicker(labelText: "结束时间",
                                          date: self.task.normalizedEndDate ?? Date(),
                                          valueDidChange: { [unowned self] date in
                    task.normalizedEndDate = date
                }))
                .tag("endDate")
            }
            .tag("2")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavigationBar()
        reload(animating: false)
    }
}

extension TaskEditorViewController {
    func setupNavigationBar() {
        title = "Edit Task"
        
        navigationItem.rightBarButtonItems = [
            makeDoneButton { [unowned self] in
                presentingViewController?.dismiss(animated: true)
            }
        ]
    }
}
