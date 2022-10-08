//
//  EventHandling.swift
//  
//
//  Created by Kai Shao on 2022/9/6.
//

import UIKit
import EventKit
import EventKitUtils

public protocol TaskHandling {
    var em: EventManager { get }
    func taskHandling(presentErrorAlertControllerOn withError: Error) -> UIViewController
}

public extension TaskHandling {
    func saveTaskAndPresentErrorAlert(_ task: TaskValue, commit: Bool = true) async -> Bool {
        do {
            try await em.saveTask(task, commit: commit)
            
            return true
        } catch {
            await handleError(error: error)
            
            return false
        }
    }
    
    func saveEventAndPresentErrorAlert(_ event: EKEvent, commit: Bool = true) async -> Bool {
        do {
            try em.eventStore.save(event, span: .thisEvent, commit: commit)
            
            return true
        } catch {
            await handleError(error: error)
            
            return false
        }
    }
    
    func saveTasksAndPresentErrorAlert(_ tasks: [TaskValue]) async -> Bool {
        do {
            try await em.saveTasks(tasks)
            
            return true
        } catch {
            await handleError(error: error)
            
            return false
        }
    }
    
    func toggleCompletionOrPresentError(_ task: TaskValue) async -> Bool {
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
        let vc = taskHandling(presentErrorAlertControllerOn: error)
        
        await vc.presentAlertController(title: "alert_title_task_save_failed".loc, message: message, actions: [.ok()])
    }
}
