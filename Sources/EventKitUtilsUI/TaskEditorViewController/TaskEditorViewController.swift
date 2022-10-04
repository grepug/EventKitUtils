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
    var task: TaskKind
    var keyResultInfo: KeyResultInfo?
    var originalTaskValue: TaskValue
    unowned public let em: EventManager
    var cancellables = Set<AnyCancellable>()
    
    public var onDismiss: ((Bool) -> Void)?
    
    public init(task: TaskValue, eventManager: EventManager) {
        self.task = task
        self.em = eventManager
        self.originalTaskValue = task
        
        super.init(nibName: nil, bundle: nil)
    }
    
    deinit {
        print("deinit, TaskEditorVC")
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var config: EventConfiguration {
        em.configuration
    }
    
    var uiConfig: EventUIConfiguration {
        em.uiConfiguration!
    }
    
    var eventStore: EKEventStore {
        em.eventStore
    }
    
    var datePickerMode: UIDatePicker.Mode {
        task.normalizedIsAllDay ? .date : .dateAndTime
    }
    
    var event: EKEvent? {
        task as? EKEvent
    }
    
    var isEvent: Bool {
        event != nil
    }
    
    var isCreating: Bool {
        originalTaskValue.isEmpty
    }
    
    var hasChanges: Bool {
        if let event {
            return event.value != originalTaskValue
        }
        
        return task.value != originalTaskValue
    }
    
    var hasNoError: Bool {
        if let event {
            return event.dateErrorMessage == nil &&
            event.recurrencePrompt(withKRinfo: keyResultInfo) == nil
        }
        
        return task.dateErrorMessage == nil
    }
    
    public override var list: DLList {
        DLList { [unowned self] in
            self.titleSection
            self.keyResultLinkingSection
            self.plannedDateSection
            self.calendarLinkingSection
            self.remarkSection
            self.deleteButton
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        isModalInPresentation = true
        setupNavigationBar()
        
        if isCreating && em.isDefaultSyncingToCalendarEnabled {
            Task {
                await convertToEvent(showingToastActivity: false)
                reload(animating: false)
            }
        } else if task.kindIdentifier == .event {
            Task {
                guard let event = await em.taskObject(task) as? EKEvent else {
                    return
                }
                
                self.task = event
                self.originalTaskValue = event.value
                
                // set a default end date for recurrence if it absents
                if event.hasRecurrenceRules {
                    if event.recurrenceEndDate == nil,
                       let startDate = event.normalizedStartDate {
                        event.setTaskRecurrenceRule(event.taskRecurrenceRule, end: .init(end: startDate.nextWeek))
                    }
                }
                
                reload(animating: false)
            }
        } else {
            reload(animating: false)
        }
        
        titleTextFieldBecomeFirstResponder()
        
        setupKeyboardSubscribers(scrollView: listView,
                                 storeIn: &cancellables) { [weak self] view in
            guard let self = self else { return nil }
            
            guard let collectionViewCell = view?.collectionViewCell,
                  let indexPath = self.listView.indexPath(for: collectionViewCell),
                  indexPath.section > 0 else {
                return nil
            }
            
            return [indexPath.section, 0]
        } onPopup: { [weak self] indexPath in
            self?.listView.scrollToItem(at: indexPath, at: .top, animated: true)
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
        
        keyResultInfo = await config.fetchKeyResultInfo(byID: id)
    }
}

extension TaskEditorViewController: TaskHandling {
    func titleTextFieldBecomeFirstResponder() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.becomeFirstResponder(at: [0, 0])
        }
    }
    
    func setupNavigationBar() {
        title = "task_editor_title".loc
        
        setupDoneButton()
        setupCancelButton()
    }
    
    func doneEditor() async {
        if let errorMessage = task.dateErrorMessage {
            presentErrorAlert(title: errorMessage)
            return
        }
        
        if let errorMessage = event?.recurrencePrompt(withKRinfo: keyResultInfo) {
            presentErrorAlert(title: errorMessage)
            return
        }
        
        guard !task.isEmpty else {
            await em.deleteTask(task)
            dismissEditor()
            return
        }
        
        let finalAction: () async -> Void = { [weak self] in
            guard let self = self else { return }
            
            guard await self.saveTaskAndPresentErrorAlert(self.task, creating: self.isCreating) else {
                return
            }
            
            self.dismissEditor(shouldOpenTaskList: self.isCreating)
        }
        
        guard !isCreating, !task.isCompleted, hasChanges else {
            await finalAction()
            return
        }
        
        guard task.testAreDatesSame(from: originalTaskValue) else {
            await finalAction()
            return
        }
        
        let tasks = await em.fetchTasks(with: .repeatingInfo(originalTaskValue.repeatingInfo))
        
        guard tasks.count > 1 else {
            await finalAction()
            return
        }
        
        guard let savingFutureTasks = await presentSaveRepeatingTaskAlert() else {
            /// user canceled
            return
        }
        
        if savingFutureTasks {
            let currentTask = self.task
            var savingTaskObjects: [TaskKind] = []
            let uniquedTasks = ([currentTask] + tasks).uniquedById
            
            for task in uniquedTasks {
                var taskObject = await em.taskObject(task)!
                
                taskObject.assignAsRepeatingTask(from: currentTask)
                savingTaskObjects.append(taskObject)
            }
            
            guard await saveTasksAndPresentErrorAlert(savingTaskObjects) else {
                return
            }
        } else {
            guard await saveTaskAndPresentErrorAlert(task) else {
                return
            }
        }
        
        dismissEditor()
    }
    
    func presentSaveRepeatingTaskAlert() async -> Bool? {
        let actions: [ActionValue] = [
            .init(title: "task_editor_save_only_this_task".loc, style: .destructive),
            .init(title: "task_editor_save_future_tasks".loc, style: .destructive),
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
            if task.kindIdentifier == .event {
                await em.deleteTask(task)
            }
            
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
            if task.isValueType {
                dismissEditor()
                return
            }
            
            let deleted = await em.handleDeleteTask(task: task.value, on: self)
            
            if deleted {
                dismissEditor()
            }
        case discard:
            dismissEditor()
        default: break
        }
    }
    
    func presentErrorAlert(title: String) {
        presentAlertController(title: title, message: nil, actions: [.ok()])
    }
    
    func dismissEditor(shouldOpenTaskList: Bool = false) {
        onDismiss?(shouldOpenTaskList)
        presentingViewController?.dismiss(animated: true)
    }
}

private extension TaskEditorViewController {
    func log(_ msg: String) {
        uiConfig.log(msg + " at TaskEditorViewController")
    }
    
    func setupDoneButton() {
        log("before setupDoneButton")
        
        let doneButton = UIBarButtonItem(systemItem: .done, primaryAction: .init { [weak self] _ in
            guard let self = self else { return }
            
            self.log("before done action")
            
            self.view.endEditing(true)
            
            Task {
                await self.doneEditor()
                
                self.log("after done action")
            }
        })
        
        doneButton.isEnabled = hasNoError
        
        navigationItem.rightBarButtonItem = doneButton
        
        log("after setupDoneButton")
    }
    
    func setupCancelButton() {
        log("before setupCancelButton")
        
        let cancelButton = UIBarButtonItem(systemItem: .cancel, primaryAction: .init { [weak self] _ in
            guard let self = self else { return }
            
            self.log("before cancelButton action")
            
            self.view.endEditing(true)
            
            Task {
                await self.handleCancelEditor()
                
                self.log("after cancelButton action")
            }
        })
        
        navigationItem.leftBarButtonItem = cancelButton
        
        log("after setupCancelButton")
    }
}

public extension EventManager {
    @MainActor
    func makeTaskEditorViewController(task _task: TaskValue? = nil, onDismiss: ((Bool) -> Void)? = nil) async -> UIViewController {
        let task: TaskValue
        
        if let _task {
            task = _task
        } else {
            let startDate = Date().startOfHour
            let endDate = startDate.nextHour
            
            task = .init(normalizedTitle: "",
                         normalizedStartDate: startDate,
                         normalizedEndDate: endDate)
        }
        
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
