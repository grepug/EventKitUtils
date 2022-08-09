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
    
    public override func reload(applyingSnapshot: Bool = true, animating: Bool = true) {
        super.reload(applyingSnapshot: applyingSnapshot, animating: animating)
        setupNavigationBar()
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
               let button = UIBarButtonItem.init(systemItem: .trash, primaryAction: .init { [unowned self] _ in
                    Task {
                        await em.handleDeleteTask(task: task.value, on: self)
                        dismissEditor()
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
        
        if let errorMessage = task.dateErrorMessage {
            presentDateRangeErrorAlert(title: errorMessage)
            return
        }
        
        guard !task.isEmpty else {
            await em.deleteTask(task)
            dismissEditor()
            return
        }
        
        if task.value != originalTaskValue,
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
        dismissEditor(shouldOpenTaskList: originalTaskValue.isEmpty)
    }
    
    func presentSaveRepeatingTaskAlert(count: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [unowned self] in
                presentAlertController(title: "重复任务", message: "", actions: [
                    .init(title: "仅保存此任务", style: .default) { _ in
                        continuation.resume(returning: false)
                    },
                    .init(title: "保存将来所有未完成的任务(\(count))", style: .default) { _ in
                        continuation.resume(returning: true)
                    },
                    .cancel
                ])
            }
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
