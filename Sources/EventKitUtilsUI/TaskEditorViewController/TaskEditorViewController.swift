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
import Combine
import UIKitUtils

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
    var cancellables = Set<AnyCancellable>()
    var forceReloadToggleFlag = 0
    
    public var onDismiss: ((Bool) -> Void)?
    
    public init(task: TaskKind, eventManager: EventManager) {
        self.task = task.isValueType ? eventManager.taskObject(task) : task
        self.em = eventManager
        self.originalTaskValue = task.value
        
        super.init(nibName: nil, bundle: nil)
    }
    
    deinit {
        print("deinit, TaskEditorVC")
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
        task.normalizedIsAllDay ? .date : .dateAndTime
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            becomeFirstResponder(at: [0, 0])
        }
        
        setupKeyboardSubscribers(scrollView: listView,
                                 storeIn: &cancellables) { [unowned self] view in
            guard let collectionViewCell = view?.collectionViewCell,
                  let indexPath = listView.indexPath(for: collectionViewCell),
                  indexPath.section > 0 else {
                return nil
            }
            
            return [indexPath.section, 0]
        } onPopup: { [unowned self] indexPath in
            listView.scrollToItem(at: indexPath, at: .top, animated: true)
        }
    }
    
    public override func reload(applyingSnapshot: Bool = true, animating: Bool = true, options: Set<DiffableListViewController.ReloadingOption> = []) {
        super.reload(applyingSnapshot: applyingSnapshot, animating: animating, options: options)
        setupNavigationBar()
        
        Task {
            await fetchKeyResultInfo()
            super.reload(applyingSnapshot: applyingSnapshot, animating: animating)
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
        title = "task_editor_title".loc
        
        setupDoneButton()
        setupCancelButton()
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
        
        if !isCreating, !task.isCompleted, hasChanges,
           task.testAreDatesSame(from: originalTaskValue),
           let endDate = originalTaskValue.normalizedEndDate {
            let tasks = await em.fetchTasks(with: .repeatingInfo(originalTaskValue.repeatingInfo))
            let futureTasks = tasks.incompletedTasksAfter(endDate, notEqualTo: originalTaskValue)
            
            if !futureTasks.isEmpty {
                guard let savingFutureTasks = await presentSaveRepeatingTaskAlert(count: futureTasks.count) else {
                    /// user canceled
                    return
                }
                
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
    
    func presentSaveRepeatingTaskAlert(count: Int) async -> Bool? {
        let actions: [ActionValue] = [
            .init(title: "task_editor_save_only_this_task".loc, style: .destructive),
            .init(title: "task_editor_save_future_tasks".loc("\(count)"), style: .destructive),
            .cancel
        ]
        
        let result = await presentAlertController(title: "task_editor_save_alert_title".loc, message: nil, actions: actions)
        
        switch result {
        case actions[0]: return false
        case actions[1]: return true
        case actions[2]: return nil
        default: fatalError()
        }
    }
    
    func handleCancelEditor() async {
        guard !task.isEmpty else {
            await em.deleteTask(task)
            dismissEditor()
            return
        }
        
        guard isCreating || hasChanges else {
            dismissEditor()
            return
        }
        
        let actions: [ActionValue]
        let discard = ActionValue(title: "action_discard_editing".loc, style: .destructive)
        
        if isCreating {
            actions = [.delete, .cancel]
        } else {
            actions = [discard, .cancel]
        }
        
        guard let result = await presentAlertController(title: "action_discard_editing_title".loc, message: nil, actions: actions) else {
            return
        }
        
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

private extension TaskEditorViewController {
    func setupDoneButton() {
        let doneButton = UIBarButtonItem(systemItem: .done, primaryAction: .init { [weak self] _ in
            guard let self = self else { return }
            
            self.view.endEditing(true)
            
            Task {
                await self.doneEditor()
            }
        })
        
        doneButton.isEnabled = task.dateErrorMessage == nil
        
        navigationItem.rightBarButtonItem = doneButton
    }
    
    func setupCancelButton() {
        navigationItem.leftBarButtonItems = [
            {
                let button = UIBarButtonItem.init(systemItem: .cancel, primaryAction: .init { [weak self] _ in
                    guard let self = self else { return }
                    
                    Task {
                        self.view.endEditing(true)
                        await self.handleCancelEditor()
                    }
                })
                
                return button
            }()
        ]
    }
}

public extension EventManager {
    func makeTaskEditorViewController(task: TaskKind? = nil, onDismiss: ((Bool) -> Void)? = nil) -> UIViewController {
        let task = task ?? fetchOrCreateTaskObject()!
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
                return "task_editor_date_range_error_end_cannot_earlier_than_start".loc
            }
        }
        
        return nil
    }
}
