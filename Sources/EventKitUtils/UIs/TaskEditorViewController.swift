//
//  TaskEditorViewController.swift
//  
//
//  Created by Kai on 2022/7/21.
//

import DiffableList
import UIKit
import SwiftUI

open class TaskEditorViewController: DiffableListViewController {
    var task: TaskKind
    
    init(task: TaskKind) {
        self.task = task
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var datePickerMode: UIDatePicker.Mode {
        task.isAllDay ? .date : .dateAndTime
    }
    
    open override var list: DLList {
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
            
            DLSection { [unowned self] in
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
                                          date: task.normalizedStartDate ?? Date(),
                                          mode: datePickerMode,
                                          valueDidChange: { [unowned self] date in
                    task.normalizedStartDate = date
                }))
                .tag("startDate \(task.normalizedStartDate?.description ?? "") \(datePickerMode.rawValue)")
                
                DLCell(using: .datePicker(labelText: "结束时间",
                                          date: task.normalizedEndDate ?? Date(),
                                          mode: datePickerMode,
                                          valueDidChange: { [unowned self] date in
                    task.normalizedEndDate = date
                }))
                .tag("endDate \(task.normalizedEndDate?.description ?? "") \(datePickerMode.rawValue)")
            }
            .tag("2")
            
            DLSection {
                DLCell {
                    DLText("关联关键结果")
                        .color(.accentColor)
                }
                .tag("link kr")
                .onTapAndDeselect { [unowned self] _ in
                    presentKeyResultSelector { [unowned self] krID in
                        task.keyResultId = krID
                    }
                }
            }
            .tag("3")
            
            DLSection {
                DLCell {
                    DLText("同步到系统日历")
                    DLText("设置提醒、重复任务")
                        .secondary()
                        .color(.secondaryLabel)
                }
                .tag("calendar")
                .accessories([.label("开启"), .disclosureIndicator()])
            }
            .tag("4")
            
            DLSection { [unowned self] in
                DLCell(using: .textEditor(text: task.notes,
                                          placeholder: "v3_task_editor_remark".loc,
                                          action: { [unowned self] text in
                    task.notes = text
                }))
                .tag("remarkEditor")
            }
            .tag("remark")
        }
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavigationBar()
        reload(animating: false)
    }
    
    open func presentKeyResultSelector(action: @escaping (String) -> Void) {}
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
