//
//  File.swift
//  
//
//  Created by Kai on 2022/8/8.
//

import UIKit
import EventKitUtils

extension EventManager {
    /// Delete the task, present the "deleting future tasks" alert if it is a repeating task
    ///
    /// Deletion flow:
    /// - if the task is completed, delete it
    /// - if the task is not completed
    ///     - if it is repeating, presenting the alert to user to choose whether delete only this one
    ///     - or all future tasks
    ///     - otherwise, delete this task
    ///
    ///
    /// - Parameters:
    ///   - task: the task value to delete
    ///   - vc: the ``UIViewController`` it is preseted on
    ///   - removeTask: the handler to manually remove this task in the current view model
    /// - Returns: a boolean that indicates if deleted successfully
    @discardableResult
    func handleDeleteTask(task: TaskValue, on vc: UIViewController, manuallyRemoveThisTaskSinceItIsTheLastOne removeTask: (() -> Void)? = nil) async -> Bool {
        if task.isCompleted {
            removeTask?()
            await self.deleteTask(task)

            return true
        }
        
        if task.isRpeating {
            let deletionOptions = await presentDeletingTasksAlert(parentVC: vc)
            
            switch deletionOptions {
            case .canceled:
                return false
            case .deletingThis:
                await self.deleteTask(task)
                
                return true
            case .deletingAll:
                removeTask?()
//                await self.deleteTasks(tasks)
                
                return true
            }
        } else {
            removeTask?()
            await self.deleteTask(task)

            return true
        }
    }
    
    private enum DeletionTasksAlertOption {
        case canceled, deletingThis, deletingAll
    }
    
    private func presentDeletingTasksAlert(parentVC: UIViewController) async -> DeletionTasksAlertOption {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [unowned parentVC] in
                parentVC.presentAlertController(title: "alert_title_deleting_repeat_tasks".loc,
                                                message: nil,
                                                actions: [
                                                    .cancel {
                                                        continuation.resume(returning: .canceled)
                                                    },
                                                    .init(title: "alert_action_delete_this_task".loc, style: .destructive) { _ in
                                                        continuation.resume(returning: .deletingThis)
                                                    },
                                                    .init(title: "alert_action_delete_all_tasks".loc, style: .destructive) { _ in
                                                        continuation.resume(returning: .deletingAll)
                                                    }
                                                ])
            }
        }
    }
}
