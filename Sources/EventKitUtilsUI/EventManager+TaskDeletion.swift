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
        
        let tasks = await fetchTasks(with: .repeatingInfo(task.repeatingInfo))

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
                parentVC.presentAlertController(title: "此为重复任务，您确定要删除此任务吗？",
                                                message: nil,
                                                actions: [
                                                    .cancel {
                                                        continuation.resume(returning: .canceled)
                                                    },
                                                    .init(title: "仅删除此任务", style: .destructive) { _ in
                                                        continuation.resume(returning: .deletingThis)
                                                    },
                                                    .init(title: "删除将来所有任务", style: .destructive) { _ in
                                                        continuation.resume(returning: .deletingAll)
                                                    }
                                                ])
            }
        }
    }
}
