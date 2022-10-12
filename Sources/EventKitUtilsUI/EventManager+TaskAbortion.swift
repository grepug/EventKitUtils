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
    ///   - onlyAbortThis: boolean that whether only abort current selected task, not prompt your to choose
    ///   - removeTask: the handler to manually remove this task in the current view model
    /// - Returns: a boolean that indicates if aborted successfully
    @discardableResult
    func handleToggleAbortingTask(task: TaskValue, on vc: UIViewController, onlyAbortThis: Bool, manuallyRemoveThisTaskSinceItIsTheLastOne removeTask: (() -> Void)? = nil) async -> Bool {
        let isToAbort = !task.isAborted
        let repeatingTasks = await fetchTasks(with: .repeatingInfo(task.repeatingInfo)).tasks.filter { isToAbort ? !$0.isAborted : $0.isAborted }
        
        if !onlyAbortThis && repeatingTasks.count > 1 {
            let option = await presentAbortingTaskAlert(on: vc, isToAbort: isToAbort)
            
            switch option {
            case .canceled:
                return false
            case .this:
                await toggleAbortion(task)
                return true
            case .allIncompleted:
                if isToAbort {
                    removeTask?()
                }
                
                try! await abortTasks(repeatingTasks)
                return true
            }
        } else {
            if isToAbort {
                removeTask?()
            }
            
            await toggleAbortion(task)
            return true
        }
    }
    
    private enum AbortionTasksAlertOption {
        case canceled, this, allIncompleted
    }
    
    private func presentAbortingTaskAlert(on vc: UIViewController, isToAbort: Bool) async -> AbortionTasksAlertOption {
        let abortThisText = isToAbort ? "放弃当前任务" : "取消放弃当前任务"
        let abortAllText = isToAbort ? "放弃所有未完成任务" : "取消放弃所有任务"
        
        let actions: [UIViewController.ActionValue] = [
            .cancel,
            .init(title: abortThisText, style: .destructive),
            .init(title: abortAllText, style: .destructive),
        ]
        
        let action = await vc.presentAlertController(title: "此为重复任务，您确定要放弃吗？", message: nil, actions: actions)
        
        switch action {
        case actions[0]: return .canceled
        case actions[1]: return .this
        case actions[2]: return .allIncompleted
        default: fatalError()
        }
    }
}
