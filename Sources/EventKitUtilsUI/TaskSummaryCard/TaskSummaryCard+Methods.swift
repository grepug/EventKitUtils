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
            let tasksGroupedByTitle = tasks.titleGrouped()
            
            self.tasks = tasks
                .repeatingMerged { tasksGroupedByTitle[$0]?.count }
                .prefix(3).map { $0 }
        }
    }
}

extension TaskSummaryCard {
    func showMore() {
        let vc = TaskListViewController(eventManager: em)
        parentVC.push(vc)
    }
    
    func presentTaskEditor(task: TaskKind? = nil) {
        let task = task ?? em.config.createNonEventTask()
        let vc = TaskEditorViewController(task: task, eventManager: em)
        let nav = vc.navigationControllerWrapped()
        
        parentVC.present(nav, animated: true)
    }
}
