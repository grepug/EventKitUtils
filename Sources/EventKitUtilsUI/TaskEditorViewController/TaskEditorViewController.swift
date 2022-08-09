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
import CoreData

public class TaskEditorViewController: DiffableListViewController {
    var task: TaskKind! {
        willSet {
            if let managedObject = newValue as? NSManagedObject {
                if managedObject.managedObjectContext?.concurrencyType != .mainQueueConcurrencyType {
                    fatalError("managed task object in editor should be in main queue type")
                }
            }
        }
    }

    var keyResultInfo: KeyResultInfo?
    var originalTaskValue: TaskValue
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
    
    var isCreating: Bool {
        originalTaskValue.isEmpty
    }
    
    var hasChanges: Bool {
        task.value != originalTaskValue
    }
    
    public override var list: DLList {
        DLList { [unowned self] in
            self.titleSection
            self.plannedDateSection
            self.keyResultLinkingSection
            
            if self.task.keyResultId != nil {
                self.linkRecordSection
            }
            
            if self.task.isDateEnabled {
                self.calendarLinkingSection
            }
            
            self.remarkSection
            self.deleteButton
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        isModalInPresentation = true
        setupNavigationBar()
        reload(animating: false)
        becomeFirstResponder(at: [0, 0])
    }
    
    public override func reload(applyingSnapshot: Bool = true, animating: Bool = true) {
        Task {
            await fetchKeyResultInfo()
            super.reload(applyingSnapshot: applyingSnapshot, animating: animating)
            setupNavigationBar()
        }
    }
    
    func fetchKeyResultInfo() async {
        guard let id = task.keyResultId else {
            return
        }
        
        keyResultInfo = await em.config.fetchKeyResultInfo(id)
    }
}

extension TaskEditorViewController {
    func setupNavigationBar() {
        title = "Edit Task"
        
        navigationItem.rightBarButtonItems = [
            { [unowned self] in
                let button = UIBarButtonItem.makeDoneButton(on: self) { [unowned self] in
                    await doneEditor()
                }
                
                button.isEnabled = task.dateErrorMessage == nil
                
                return button
            }()
        ]
        
        navigationItem.leftBarButtonItems = [
            {
               let button = UIBarButtonItem.init(systemItem: .cancel, primaryAction: .init { [unowned self] _ in
                    Task {
                        view.endEditing(true)
                        await handleCancelEditor()
                    }
                })
                
                return button
            }()
        ]
    }
    
    func doneEditor() async {
        if let errorMessage = task.dateErrorMessage {
            presentDateRangeErrorAlert(title: errorMessage)
            return
        }
        
        guard !task.isEmpty else {
            await em.deleteTask(task)
            dismissEditor()
            return
        }
        
        if hasChanges,
           task.testAreDatesSame(from: originalTaskValue),
           let endDate = originalTaskValue.normalizedEndDate {
            let tasks = await em.fetchTasks(with: .title(originalTaskValue.normalizedTitle))
            let futureTasks = tasks.incompletedTasksAfter(endDate, notEqualTo: originalTaskValue)
            
            if !futureTasks.isEmpty {
                let savingFutureTasks = await presentSaveRepeatingTaskAlert(count: futureTasks.count)
                
                if savingFutureTasks {
                    var savingTaskObjects: [TaskKind] = []
                    
                    for task in futureTasks {
                        var taskObject = em.taskObject(task)!
                        
                        taskObject.assignAsRepeatingTask(from: self.task)
                        savingTaskObjects.append(taskObject)
                    }
                    
                    await em.saveTasks(savingTaskObjects + [self.task])
                } else {
                    await em.saveTask(task)
                }
                
                dismissEditor()
                
                return
            }
        }
        
        await em.saveTask(task)
        dismissEditor(shouldOpenTaskList: isCreating)
    }
    
    
    
    func presentSaveRepeatingTaskAlert(count: Int) async -> Bool {
        let actions: [ActionValue] = [
            .init(title: "仅保存此任务", style: .destructive),
            .init(title: "保存将来所有未完成的任务(\(count))", style: .destructive),
            .cancel
        ]
        
        let result = await presentAlertController(title: "重复任务", message: nil, actions: actions)
        
        switch result {
        case actions[0]: return false
        case actions[1]: return true
        case actions[2]: return false
        default: fatalError()
        }
    }
    
    func handleCancelEditor() async {
        guard isCreating || hasChanges else {
            dismissEditor()
            return
        }
        
        let actions: [ActionValue]
        let discard = ActionValue(title: "放弃更改", style: .destructive)
        
        if isCreating {
            actions = [.delete, .cancel]
        } else {
            actions = [discard, .cancel]
        }
        
        let result = await presentAlertController(title: "取消后编辑丢失", message: nil, actions: actions)
        
        switch result {
        case .delete:
            let deleted = await em.handleDeleteTask(task: task.value, on: self)
            if deleted {
                dismissEditor()
            }
        case discard:
            dismissEditor()
        default: break
        }
    }
    
    func presentDateRangeErrorAlert(title: String) {
        presentAlertController(title: title, message: nil, actions: [.ok()])
    }
    
    func dismissEditor(shouldOpenTaskList: Bool = false) {
        onDismiss?(shouldOpenTaskList)
        presentingViewController?.dismiss(animated: true)
    }
}

public extension EventManager {
    func makeTaskEditorViewController(task: TaskKind, onDismiss: ((Bool) -> Void)? = nil) -> UIViewController {
        let vc = TaskEditorViewController(task: task, eventManager: self)
        let navVC = UINavigationController(rootViewController: vc)
        
        navVC.modalPresentationStyle = .formSheet
        vc.onDismiss = onDismiss
        
        return navVC
    }
}

extension TaskKind {
    var dateErrorMessage: String? {
        if isDateEnabled {
            guard dateRange != nil else {
                return "结束日期不能早于开始日期"
            }
        }
        
        return nil
    }
}
