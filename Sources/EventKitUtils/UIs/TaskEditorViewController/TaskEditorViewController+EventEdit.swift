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
    func presentEventEditor(_ task: TaskKind) {
        guard let event = task as? EKEvent else {
            return
        }
        
        event.calendar = eventStore.defaultCalendarForNewEvents
        saveTask(task)
            
        let vc = EKEventEditViewController()
        vc.event = event
        vc.eventStore = eventStore
        vc.editViewDelegate = self
        
        present(vc, animated: true)
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
