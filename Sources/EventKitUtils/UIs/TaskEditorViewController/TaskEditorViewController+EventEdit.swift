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
    func presentEventEditor() {
        guard let task = taskObject(task) else {
            return
        }
        
        let event: EKEvent
        
        if let _event = task as? EKEvent {
            event = _event
        } else {
            event = .init(baseURL: config.eventBaseURL, eventStore: eventStore)
            event.copy(from: task)
            deleteTask(task)
            self.task = event
        }
        
        event.calendar = eventStore.defaultCalendarForNewEvents
        saveTask(event)
            
        let vc = EKEventEditViewController()
        vc.event = event
        vc.eventStore = eventStore
        vc.editViewDelegate = self
        
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
            break
        case .cancelled:
            break
        @unknown default:
            break
        }
    }
}
