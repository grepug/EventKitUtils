//
//  File.swift
//  
//
//  Created by Kai on 2022/8/8.
//

import UIKit
import EventKitUtils

extension EventManager {
    @discardableResult
    func handleDeleteTask(task: TaskValue, on vc: UIViewController, manuallyRemoveThisTaskSinceItIsTheLastOne removeTask: (() -> Void)? = nil) async -> Bool {
        if task.isCompleted {
            removeTask?()
            await self.deleteTask(task)

            return true
        }
        
        let tasks = await fetchTasks(with: .repeatingInfo(task.repeatingInfo), onlyFirst: false)

        if tasks.count > 1 {
            let deletionOptions = await presentDeletingTasksAlert(parentVC: vc)
            
            switch deletionOptions {
            case .canceled:
                return false
            case .deletingThis:
                await self.deleteTask(task)
                
                return true
            case .deletingAll:
                removeTask?()
                await self.deleteTasks(tasks)
                
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
