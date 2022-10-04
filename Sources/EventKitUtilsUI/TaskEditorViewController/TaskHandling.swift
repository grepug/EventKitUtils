//
//  EventHandling.swift
//  
//
//  Created by Kai Shao on 2022/9/6.
//

import UIKit
import EventKitUtils

public protocol TaskHandling: UIViewController {
    var em: EventManager { get }
}

public extension TaskHandling {
    func saveTaskAndPresentErrorAlert(_ task: TaskKind, commit: Bool = true, creating: Bool = false) async -> Bool {
        do {
            try await em.saveTask(task, commit: commit, creating: creating)
            
            return true
        } catch {
            await handleError(error: error)
            
            return false
        }
    }
    
    func saveTasksAndPresentErrorAlert(_ tasks: [TaskKind]) async -> Bool {
        do {
            try await em.saveTasks(tasks)
            
            return true
        } catch {
            await handleError(error: error)
            
            return false
        }
    }
    
    private func handleError(error: Error) async {
        let nsError = error as NSError
        let message = nsError.localizedDescription
        
        await presentAlertController(title: "alert_title_task_save_failed".loc, message: message, actions: [.ok()])
    }
}
