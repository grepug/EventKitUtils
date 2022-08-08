//
//  File.swift
//  
//
//  Created by Kai on 2022/8/8.
//

import UIKit

extension EventManager {
    @discardableResult
    public func handleDeleteTask(task: TaskValue, on vc: UIViewController, removeTask: (() -> Void)? = nil) async -> Bool {
        let tasks = await fetchTasks(with: .title(task.normalizedTitle))

        if tasks.count > 1 {
            let deletionOptions = await presentDeletingTasksAlert(parentVC: vc)
            
            switch deletionOptions {
            case .canceled:
                return false
            case .deletingThis:
                await self.deleteTask(task)
                
                return true
            case .deletingAll:
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
            presentDeletingTasksAlert(parentVC: parentVC) { option in
                continuation.resume(returning: option)
            }
        }
    }
    
    private func presentDeletingTasksAlert(parentVC: UIViewController, handler: @escaping (DeletionTasksAlertOption) -> Void) {
        let ac = UIAlertController(title: "删除所有？", message: "", preferredStyle: .alert)
        
        ac.addAction(.init(title: "action_cancel".loc, style: .cancel, handler: { _ in
            handler(.canceled)
        }))
        
        ac.addAction(.init(title: "仅删除当前", style: .destructive, handler: { _ in
            handler(.deletingThis)
        }))
        ac.addAction(.init(title: "删除所有", style: .destructive, handler: { _ in
            handler(.deletingAll)
        }))
        
        DispatchQueue.main.async {
            parentVC.present(ac, animated: true)
        }
    }
}
