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
                self.present(vc.navigationControllerWrapped(), animated: true)
            }
        ])
    }
    
    func convertToEvent() async {
        _ = view.endEditing(true)
        
        try! await Task.sleep(nanoseconds: 50_000_000)
        
        guard !em.checkIfExceedsNonProLimit() else {
            uiConfig.presentNonProErrorAlert()
            return
        }
        
        if let errorMessage = task.dateErrorMessage {
            presentDateRangeErrorAlert(title: errorMessage)
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
        
        view.makeToastActivity(.center)
        
        var event = EKEvent(baseURL: config.eventBaseURL, eventStore: eventStore)
        event.calendar = calendar
        event.assignFromTaskKind(task)
        
        await saveTaskAndPresentErrorAlert(event)
        originalTaskValue = event.value
        
        self.task = event
        
        try! await Task.sleep(nanoseconds: 200_000_000)
        
        view.hideToastActivity()
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
}
