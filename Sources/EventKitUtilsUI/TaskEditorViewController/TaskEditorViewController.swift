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
import EventKitUtils
import TextEditorCellConfiguration

public class TaskEditorViewController: DiffableListViewController {
    var task: TaskKind!
    let originalTaskValue: TaskValue
    unowned let em: EventManager
    
    public var onDismiss: ((Bool) -> Void)?
    
    public init(task: TaskKind, eventManager: EventManager) {
        self.task = task.isValueType ? eventManager.taskObject(task) : task
        self.em = eventManager
        self.originalTaskValue = task.value
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var config: TaskConfig {
        em.config
    }
    
    var eventStore: EKEventStore {
        em.eventStore
    }
    
    var datePickerMode: UIDatePicker.Mode {
        task.isAllDay ? .date : .dateAndTime
    }
    
    var isEvent: Bool {
        task.kindIdentifier == .event
    }
    
    public override var list: DLList {
        DLList { [unowned self] in
            self.titleSection
            self.plannedDateSection
            self.keyResultLinkingSection
            
            if self.task.keyResultId != nil {
                self.linkRecordSection
            }
            
            self.calendarLinkingSection
            self.remarkSection
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        isModalInPresentation = true
        setupNavigationBar()
        reload(animating: false)
        becomeFirstResponder(at: [0, 0])
    }
}

extension TaskEditorViewController {
    func setupNavigationBar() {
        title = "Edit Task"
        
        navigationItem.rightBarButtonItems = [
            .makeDoneButton(on: self) { [unowned self] in
                await doneEditor()
            }
        ]
        
        navigationItem.leftBarButtonItems = [
            {
               let button = UIBarButtonItem.init(systemItem: .trash, primaryAction: .init { [unowned self] _ in
                    Task {
                        await em.handleDeleteTask(task: task.value, on: self)
                        dismissEditor(deleted: true)
                    }
                })
                
                button.tintColor = .systemRed
                
                return button
            }()
        ]
    }
    
    func doneEditor() async {
        view.endEditing(true)
        
        try? await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
        
        if task.isDateEnabled {
            guard task.dateRange != nil else {
                presentDateRangeErrorAlert()
                return
            }
        }
        
        guard !task.isEmpty else {
            await em.deleteTask(task)
            dismissEditor(deleted: true)
            return
        }
        
        if task.value != originalTaskValue,
           task.testAreDatesSame(from: originalTaskValue),
           let endDate = originalTaskValue.normalizedEndDate {
            let tasks = await em.fetchTasks(with: .title(originalTaskValue.normalizedTitle))
            let futureTasks = tasks.incompletedTasksAfter(endDate, notEqualTo: originalTaskValue)
            
            if !futureTasks.isEmpty {
                presentSaveRepeatingTaskAlert(count: futureTasks.count) { [unowned self] in
                    var savingTaskObjects: [TaskKind] = []
                    
                    for task in futureTasks {
                        var taskObject = em.taskObject(task)!
                        
                        taskObject.saveAsRepeatingTask(from: self.task)
                        savingTaskObjects.append(taskObject)
                    }
                    
                    em.saveTasks(savingTaskObjects + [self.task])
                }
                
                return
            }
        }
        
        em.saveTask(task)
        dismissEditor()
    }
    
    func presentSaveRepeatingTaskAlert(count: Int, savingFutureTasks: @escaping () -> Void) {
        presentAlertController(title: "重复任务", message: "", actions: [
            .init(title: "仅保存此任务", style: .default) { [unowned self] _ in
                em.saveTask(task)
                dismissEditor()
            },
            .init(title: "保存将来所有未完成的任务(\(count))", style: .default) { [unowned self] _ in
                savingFutureTasks()
                dismissEditor()
            },
            .cancel
        ])
    }
    
    func presentDateRangeErrorAlert() {
        presentAlertController(title: "结束日期不能早于开始日期", message: nil, actions: [.ok()])
    }
    
    func dismissEditor(deleted: Bool = false) {
        if !deleted {
            em.saveTask(task)
        }
        
        onDismiss?(deleted)
        presentingViewController?.dismiss(animated: true)
    }
}
