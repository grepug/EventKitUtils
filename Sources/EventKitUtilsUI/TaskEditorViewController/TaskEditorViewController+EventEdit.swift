//
//  File.swift
//  
//
//  Created by Kai on 2022/7/23.
//

import UIKit
import EventKit
import EventKitUI

extension TaskEditorViewController {
    func presentEventSettingsAlert() {
        presentAlertController(title: "task_editor_calendar_not_authorized_title".loc, message: nil, actions: [
            .cancel,
            .init(title: "task_editor_calendar_not_authorized_action".loc, style: .default) { [weak self] _ in
                guard let self = self else { return }
                
                let vc = EventSettingsViewController(eventManager: self.em)
                vc.onDismiss = { [weak self] in
                    guard let self else { return }
                    guard self.em.isEventStoreAuthorized else {
                        return
                    }
                    
                    Task {
                        await self.convertToEvent(showingToastActivity: false)
                        self.reload()
                    }
                }
                
                
                let nav = vc.navigationControllerWrapped()
                nav.modalPresentationStyle = .formSheet
                self.present(nav, animated: true)
            }
        ])
    }
    
    func convertToEvent(showingToastActivity: Bool = true) async {
        if showingToastActivity {
            _ = view.endEditing(true)
            
            try! await Task.sleep(nanoseconds: 5_000_000)
        }
        
        guard await !em.checkIfExceedsNonProLimit() else {
            uiConfig.presentNonProErrorAlert(on: self)
            return
        }
        
        if let errorMessage = taskDateError?.errorMessage {
            presentErrorAlert(title: errorMessage)
            return
        }
        
        guard task.isDateEnabled else {
            return
        }
        
        guard em.isEventStoreAuthorized else {
            presentEventSettingsAlert()
            return
        }
        
        guard let calendar = em.defaultCalendarToSaveEvents else {
            return
        }
        
        if showingToastActivity {
            view.makeToastActivity(.center)
        }
        
        var event = EKEvent(baseURL: config.eventBaseURL, eventStore: eventStore)
        event.calendar = calendar
        event.assignFromTaskKind(task)
        
        if !isCreating {
            // delete the local task before being converted to event task
            await em.deleteTask(task)
        }
        
        guard await saveTaskAndPresentErrorAlert(event) else {
            return
        }
        
        originalTaskValue = event.value
        
        self.task = event
        
        if showingToastActivity {
            try! await Task.sleep(nanoseconds: 50_000_000)
            view.hideToastActivity()
        }
    }
    
    func presentEventEditor(completion: ((UIViewController) -> Void)? = nil) {
        guard let event else {
            fatalError("event is nil")
        }
        
        let vc = EKEventEditViewController()
        vc.event = event
        vc.eventStore = eventStore
        vc.editViewDelegate = self
        vc.modalPresentationStyle = .popover
        vc.popoverPresentationController?.sourceView = listView.cellForItem(at: [3, 0])
        
        present(vc, animated: true) { [weak self] in
            self?.reload(animating: false)
            completion?(vc)
        }
    }
}

extension TaskEditorViewController: EKEventEditViewDelegate {
    public func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
        switch action {
        case .canceled:
            dismiss(animated: true)
        case .saved:
            if let event = controller.event {
                // set default recurrence end date
                setDefaultRecurrenceEndIfAbsents(event: event)
            }
            
            event?.refresh()
            reload()
            
            dismiss(animated: true)
        case .deleted:
            dismissEditor()
        case .cancelled:
            break
        @unknown default:
            break
        }
    }
    
    func setDefaultRecurrenceEndIfAbsents(event: EKEvent?) {
        if let event {
            let didSet = event.setDefaultRecurrenceEndIfAbsents(savingWithEventStore: eventStore)
            
            if didSet {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.presentChangedRecurrenceEndDateToOneWeekLaterIfAbsents()
                }
            }
        }
    }
    
    func presentChangedRecurrenceEndDateToOneWeekLaterIfAbsents() {
        presentAlertController(title: "不支持设置结束重复日期为“永不”，已为你设置为一周后。", message: nil, actions: [.ok()])
    }
}
