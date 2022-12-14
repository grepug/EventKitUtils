//
//  EventHandling.swift
//  
//
//  Created by Kai Shao on 2022/9/6.
//

import UIKit
import EventKitUtils

public protocol TaskHandling {
    var em: EventManager { get }
    var taskHandlingViewController: UIViewController { get }
}

public extension TaskHandling {
    func saveTaskAndPresentErrorAlert(_ task: TaskKind, commit: Bool = true) async -> Bool {
        do {
            try await em.saveTask(task, commit: commit)
            
            return true
        } catch {
            em.config.log?("save error from saveTaskAndPresentErrorAlert: \(error.localizedDescription)")
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
    
    func toggleCompletionOrPresentError(_ task: TaskKind) async -> Bool {
        do {
            try await em.toggleCompletion(task)
            
            return true
        } catch {
            await handleError(error: error)
            
            return false
        }
    }
    
    private func handleError(error: Error) async {
        let nsError = error as NSError
        let message = nsError.localizedDescription
        
        await taskHandlingViewController.presentAlertController(title: "alert_title_task_save_failed".loc, message: message, actions: [.ok()])
    }
}
