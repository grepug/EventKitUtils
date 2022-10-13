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
    ///   - if it is repeating, presenting the alert to user to choose whether delete only this one
    ///   - or all future tasks
    ///   - otherwise, delete this task
    ///
    ///
    /// - Parameters:
    ///   - task: the task value to delete
    ///   - vc: the ``UIViewController`` it is preseted on
    ///   - onlyDeleteThis: boolean that whether only delete current selected task, not prompt your to choose
    ///   - removeTask: the handler to manually remove this task in the current view model
    /// - Returns: a boolean that indicates if deleted successfully
    @discardableResult
    func handleDeleteTask(task: TaskValue, on vc: UIViewController, onlyDeleteThis: Bool = false, manuallyRemoveThisTaskSinceItIsTheLastOne removeTask: (() -> Void)? = nil) async -> Bool {
        let repeatingTasks = await fetchTasks(with: .repeatingInfo(task.repeatingInfo)).tasks
        
        if !onlyDeleteThis && repeatingTasks.count > 1 {
            let deletionOptions = await presentDeletingTasksAlert(parentVC: vc)
            
            switch deletionOptions {
            case .canceled:
                return false
            case .deletingThis:
                await self.deleteTask(task)
                
                return true
            case .deletingIncompleted:
                removeTask?()
                await self.deleteTasks(repeatingTasks.filter { $0.state.isIncompleted })
                return true
            case .deletingAll:
                removeTask?()
                await self.deleteTasks(repeatingTasks)
                
                return true
            }
        } else {
            removeTask?()
            await self.deleteTask(task)

            return true
        }
    }
    
    private enum DeletionTasksAlertOption: CaseIterable {
        case canceled, deletingThis, deletingIncompleted, deletingAll 
        
        var actionValue: UIViewController.ActionValue {
            switch self {
            case .canceled: return .cancel
            case .deletingThis: return .init(title: "alert_action_delete_this_task".loc, style: .destructive)
            case .deletingAll: return .init(title: "alert_action_delete_all_tasks".loc, style: .destructive)
            case .deletingIncompleted: return .init(title: "alert_action_delete_all_incompleted_tasks".loc, style: .destructive)
            }
        }
        
        init(actionValue: UIViewController.ActionValue) {
            for item in DeletionTasksAlertOption.allCases {
                if item.actionValue == actionValue {
                    self = item
                    return
                }
            }
            
            self = .canceled
        }
    }
    
    private func presentDeletingTasksAlert(parentVC: UIViewController) async -> DeletionTasksAlertOption {
        
        let actions = DeletionTasksAlertOption.allCases.map(\.actionValue)
        guard let result = await parentVC.presentAlertController(title: "alert_title_deleting_repeat_tasks".loc,
                                                                 message: nil,
                                                                 actions: actions) else {
            return .canceled
        }
        
        let deleteOption = DeletionTasksAlertOption(actionValue: result)
        
        if deleteOption == .deletingAll {
            guard await presentDeletingAllTasksAlert(parentVC: parentVC) else {
                return .canceled
            }
        }
        
        return deleteOption
    }
    
    private func presentDeletingAllTasksAlert(parentVC: UIViewController) async -> Bool {
        await parentVC.presentAlertController(title: "action_warning".loc,
                                              message: "alert_msg_delete_all_tasks".loc,
                                              actions: [.delete, .cancel]) == .delete
    }
}
