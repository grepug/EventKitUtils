//
//  TaskEditorViewController.swift
//  
//
//  Created by Kai on 2022/7/21.
//

import DiffableList
import UIKit
import EventKit
import EventKitUtils
import TextEditorCellConfiguration
import Combine

public class TaskEditorViewController: DiffableListViewController {
    var task: TaskKind
    var keyResultInfo: KeyResultInfo?
    var originalTaskValue: TaskValue
    var originalTaskAlarmType: TaskAlarmType?
    unowned public let em: EventManager
    var cancellables = Set<AnyCancellable>()
    
    public var onDismiss: ((Bool) -> Void)?
    
    public init(task: TaskValue, eventManager: EventManager) {
        self.task = task
        self.em = eventManager
        self.originalTaskValue = task.keyResultInfoRemoved
        
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
            return event.value != originalTaskValue ||
            event.taskAlarmType != originalTaskAlarmType
        }
        
        return task.value != originalTaskValue
    }
    
    var taskDateError: TaskDateValidationError? {
        task.validateDates(withKeyResultInfo: keyResultInfo)
    }
    
    var taskRecurrenceEndDateError: TaskRecurrenceEndDateValidationError? {
        task.validateRecurrenceEndDate(withKeyResultInfo: keyResultInfo)
    }
    
    var hasNoError: Bool {
        taskDateError == nil &&
        taskRecurrenceEndDateError == nil
    }
    
    public override var list: DLList {
        DLList { [unowned self] in
            self.titleSection
            self.keyResultLinkingSection
            self.plannedDateSection
            self.calendarLinkingSection
            self.alarmSection
            self.remarkSection
            self.deleteButton
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        reload(animating: false)
        isModalInPresentation = true
        setupNavigationBar()
        initialReload()
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
    
    func initialReload() {
        Task {
            await fetchKeyResultInfo()
            reload()
        }
        
        if isCreating && em.isDefaultSyncingToCalendarEnabled {
            if em.isEventStoreAuthorized {
                Task {
                    await convertToEvent(showingToastActivity: false)
                    reload(animating: false)
                }
            }
        } else if task.kindIdentifier == .event {
            Task {
                guard let event = await em.fetchEvent(withTaskValue: task.value, firstRecurrence: false) else {
                    return
                }
                
                // in case user changed recurrence end in Calendar app
                self.setDefaultRecurrenceEndIfAbsents(event: event)
                self.task = event
                self.originalTaskValue = event.value
                self.originalTaskAlarmType = event.taskAlarmType
                
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
    }
    
    public override func reload(applyingSnapshot: Bool = true, animating: Bool = true, options: Set<DiffableListViewController.ReloadingOption> = []) {
        super.reload(applyingSnapshot: applyingSnapshot, animating: animating, options: options)
        setupNavigationBar()
    }
    
    func fetchKeyResultInfo() async {
        guard let id = task.keyResultId else {
            return
        }
        
        keyResultInfo = await config.fetchKeyResultInfo(byID: id)
    }
}

extension TaskEditorViewController: TaskHandling {
    public func taskHandling(presentErrorAlertControllerOn withError: Error) -> UIViewController {
        self
    }
    
    func titleTextFieldBecomeFirstResponder() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.becomeFirstResponder(at: [0, 0])
        }
    }
    
    func setupNavigationBar() {
        title = "task_editor_title".loc
        
        setupDoneButton()
        setupCancelButton()
    }
    
    func doneEditor() async {
        if let errorMessage = taskDateError?.errorMessage {
            presentErrorAlert(title: errorMessage)
            return
        }
        
        if let errorMessage = taskRecurrenceEndDateError?.errorMessage {
            presentErrorAlert(title: errorMessage)
            return
        }
        
        guard !task.isEmpty else {
            await em.deleteTask(task)
            dismissEditor()
            return
        }
        
        assert(!task.normalizedTitle.isEmpty, "task's title is empty, may not saved.")
        
        let finalAction: () async -> Void = { [weak self] in
            guard let self = self else { return }
            
            // creating a non event task for the first time
            if self.isCreating && !self.isEvent {
                let newTask = await self.em.configuration.createNonEventTask()
                self.task.normalizedID = newTask.normalizedID
            }
            
            guard await self.saveTaskAndPresentErrorAlert(self.task) else {
                return
            }
            
            self.dismissEditor(shouldOpenTaskList: self.isCreating)
        }
        
        if isCreating || task.isCompleted || !hasChanges {
            await finalAction()
            return
        }
        
        // If user changed this task's one of the dates, it will no longer a repeating task, so just save this single task.
        if !task.testAreDatesSame(from: originalTaskValue) {
            await finalAction()
            return
        }
        
        let tasks = await em.fetchTasks(with: .repeatingInfo(originalTaskValue.repeatingInfo)).tasks
        
        assert(!tasks.isEmpty, "tasks should not be empty")
        
        if tasks.count <= 1 {
            await finalAction()
            return
        }
        
        if tasks.count > 1 {
            guard await presentAlertController(title: "此为重复任务", message: "所做编辑针对所有重复任务保存", actions: [.ok, .cancel]) == .ok else {
                return
            }
        }
        
        var savingTasks: [TaskKind] = []
        let uniquedTasks = ([task] + tasks).uniquedById
        
        for task in uniquedTasks {
            if var task = task as? TaskValue {
                // save the old date interval in order to fetch this underlying EKEvent with EventManager.fetchEvent(withTaskValue:firstRecurrence:)
                task.oldDateInterval = task.dateInterval
                task.assignAsRepeatingTask(from: self.task)
                
                savingTasks.append(task)
            } else {
                savingTasks.append(task)
            }
        }
        
        guard await saveTasksAndPresentErrorAlert(savingTasks) else {
            return
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
        // If task is empty and is an EKEvent, then delete it when user cancel the modal.
        // It is not necessary to delete an empty TaskValue, for it hasn't been saved.
        guard !task.isEmpty else {
            if task.kindIdentifier == .event {
                await em.deleteTask(task.value)
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
    func makeTaskEditorViewController(task _task: TaskValue? = nil, onDismiss: ((Bool) -> Void)? = nil) -> UIViewController {
        let task: TaskValue
        
        if let _task {
            task = _task
        } else {
            /// Just create an empty ``TaskValue``, saving it on editor done
            task = .newCreated
        }
        
        let vc = TaskEditorViewController(task: task, eventManager: self)
        let navVC = UINavigationController(rootViewController: vc)
        
        navVC.modalPresentationStyle = .formSheet
        vc.onDismiss = onDismiss
        
        return navVC
    }
}

extension TaskDateValidationError {
    var errorMessage: String {
        rawValue.loc
    }
}

extension TaskRecurrenceEndDateValidationError {
    var errorMessage: String {
        rawValue.loc
    }
}
