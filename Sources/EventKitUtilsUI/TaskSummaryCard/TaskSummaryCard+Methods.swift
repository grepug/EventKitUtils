//
//  File.swift
//  
//
//  Created by Kai on 2022/8/4.
//

import EventKitUtils

extension TaskSummaryCard {
    func reload() {
        Task {
            let tasks = await em.fetchTasks(with: .segment(.today))
                .repeatingMerged()
                .prefix(3).map { $0 }
            
            self.tasks = tasks
        }
    }
}

extension TaskSummaryCard {
    func presentTaskEditor(task: TaskValue? = nil) {
        let task = em.fetchOrCreateTaskObject(from: task)
        let vc = TaskEditorViewController(task: task, eventManager: em)
        let nav = vc.navigationControllerWrapped()
        
        vc.onDismiss = {
            let vc = TaskListViewController(eventManager: em)
            vc.segment = showingTodayTasks ? .today : .incompleted
            
            parentVC.navigationController?.pushViewController(vc, animated: true)
        }
        
        parentVC.present(nav, animated: true)
    }
}
