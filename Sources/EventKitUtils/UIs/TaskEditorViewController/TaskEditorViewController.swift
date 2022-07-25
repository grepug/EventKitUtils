//
//  TaskEditorViewController.swift
//  
//
//  Created by Kai on 2022/7/21.
//

import DiffableList
import UIKit
import SwiftUI
import EventKit

open class TaskEditorViewController: DiffableListViewController, TaskHandler {
    var task: TaskKind
    let eventStore: EKEventStore
    let taskConfig: TaskConfig
    
    public init(task: TaskKind, config: TaskConfig, eventStore: EKEventStore) {
        self.task = task
        self.eventStore = eventStore
        self.taskConfig = config
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var datePickerMode: UIDatePicker.Mode {
        task.isAllDay ? .date : .dateAndTime
    }
    
    var isEvent: Bool {
        task as? EKEvent != nil
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
                .tag("enable planDate \(isEvent) \(task.isDateEnabled)")
                .accessories([.toggle(isOn: task.isDateEnabled, isEnabled: !isEvent, action: { [unowned self] isOn in
                    task.isDateEnabled = isOn
                    reload()
                })])
                
                if task.isDateEnabled {
                    DLCell {
                        DLText("全天")
                    }
                    .tag("is all day \(task.isDateEnabled.description) \(task.isAllDay.description)")
                    .accessories([.toggle(isOn: task.isAllDay, action: { [unowned self] isOn in
                        task.isAllDay = isOn
                        reload()
                    })])
                    
                    DLCell(using: .datePicker(labelText: "开始时间",
                                              date: task.normalizedStartDate ?? Date(),
                                              mode: datePickerMode,
                                              valueDidChange: { [unowned self] date in
                        task.normalizedStartDate = date
                    }))
                    .tag("startDate \(task.isDateEnabled) \(task.normalizedStartDate?.description ?? "") \(datePickerMode.rawValue)")
                    
                    DLCell(using: .datePicker(labelText: "结束时间",
                                              date: task.normalizedEndDate ?? Date(),
                                              mode: datePickerMode,
                                              valueDidChange: { [unowned self] date in
                        task.normalizedEndDate = date
                    }))
                    .tag("endDate \(task.isDateEnabled) \(task.normalizedEndDate?.description ?? "") \(datePickerMode)")
                }
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
            
            DLSection { [unowned self] in
                DLCell {
                    DLText("同步到系统日历")
                    DLText("设置提醒、重复任务")
                        .secondary()
                        .color(.secondaryLabel)
                }
                .tag("calendar \(isEvent)")
                .accessories([.label(isEvent ? "已开启" : "开启"), .disclosureIndicator()])
                .onTapAndDeselect {  [unowned self] _ in
                    presentEventEditor()
                }
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
            .tag("remark \(task.notes ?? "")")
        }
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavigationBar()
        reload(animating: false)
        becomeFirstResponder(at: [0, 0])
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
