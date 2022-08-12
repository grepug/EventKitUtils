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
        presentAlertController(title: "未开启日历权限", message: "现在去开启吗？", actions: [
            .cancel,
            .init(title: "去开启", style: .default) { [unowned self] _ in
                let vc = EventSettingsViewController(eventManager: em)
                present(vc.navigationControllerWrapped(), animated: true)
            }
        ])
    }
    
    @MainActor
    func convertToEvent() async {
        view.endEditing(true)
        
        try! await Task.sleep(nanoseconds: 50_000_000)
        
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
        
        var event = EKEvent(baseURL: config.eventBaseURL, eventStore: eventStore)
        event.calendar = calendar
        event.assignFromTaskKind(task)
        
        /// 删除本地 task
        await em.deleteTask(task)
        await em.saveTask(event)
        originalTaskValue = event.value
        task = event
        
        try! await Task.sleep(nanoseconds: 200_000_000)
        reload()
    }
    
    func presentEventEditor() {
        guard let event = task as? EKEvent else {
            fatalError("this should be an ekEvent")
        }
        
        let vc = EKEventEditViewController()
        vc.event = event
        vc.eventStore = eventStore
        vc.editViewDelegate = self
        vc.modalPresentationStyle = .popover
        vc.popoverPresentationController?.sourceView = listView.cellForItem(at: [3, 0])
        
        present(vc, animated: true) { [unowned self] in
            reload(animating: false)
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
