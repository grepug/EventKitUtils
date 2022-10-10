//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/10/2.
//

import UIKit
import EventKitUtils

extension EventManager {
    /// Abort the task, presenting "aborting all tasks" alert if it is a repeating task
    /// - Parameters:
    ///   - task: the task to abort
    ///   - vc: the ``UIViewController`` it is preseted on
    ///   - removeTask: the handler to manually remove this task in the current view model
    /// - Returns: a boolean that indicates if aborted successfully
    @discardableResult
    func handleToggleAbortingTask(task: TaskValue, on vc: UIViewController, manuallyRemoveThisTaskSinceItIsTheLastOne removeTask: (() -> Void)? = nil) async -> Bool {
        let isAbortion = !task.isAborted
        let repeatingTasks = await fetchTasks(with: .repeatingInfo(task.repeatingInfo)).tasks.filter { isAbortion ? !$0.isAborted : $0.isAborted }
        
        if repeatingTasks.count > 1 {
            let option = await presentAbortingTaskAlert(on: vc)
            
            switch option {
            case .canceled:
                return false
            case .this:
                await toggleAbortion(task)
                return true
            case .allIncompleted:
                if isAbortion {
                    removeTask?()
                }
                
                try! await abortTasks(repeatingTasks)
                return true
            }
        } else {
            if isAbortion {
                removeTask?()
            }
            
            await toggleAbortion(task)
            return true
        }
    }
    
    private enum AbortionTasksAlertOption {
        case canceled, this, allIncompleted
    }
    
    private func presentAbortingTaskAlert(on vc: UIViewController) async -> AbortionTasksAlertOption {
        let actions: [UIViewController.ActionValue] = [
            .cancel,
            .init(title: "放弃当前", style: .destructive),
            .init(title: "放弃所有未完成", style: .destructive),
        ]
        
        let action = await vc.presentAlertController(title: "", message: "", actions: actions)
        
        switch action {
        case actions[0]: return .canceled
        case actions[1]: return .this
        case actions[2]: return .allIncompleted
        default: fatalError()
        }
    }
}
