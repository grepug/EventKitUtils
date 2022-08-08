//
//  File.swift
//  
//
//  Created by Kai on 2022/8/4.
//

import EventKitUtils

extension TaskSummaryCard {
    @MainActor
    func reload() async {
        tasks = await em.fetchTasks(with: .segment(.today))
            .repeatingMerged()
            .prefix(3).map { $0 }
    }
}

extension TaskSummaryCard {
    func presentTaskEditor(task: TaskValue? = nil) {
        let task = em.fetchOrCreateTaskObject(from: task)
        
        let vc = em.makeTaskEditorViewController(task: task) { shouldOpenTaskList in
            guard shouldOpenTaskList else {
                return
            }
            
            let vc = TaskListViewController(eventManager: em)
            vc.segment = showingTodayTasks ? .today : .incompleted
            
            parentVC.navigationController?.pushViewController(vc, animated: true)
        }
        
        parentVC.present(vc, animated: true)
    }
}
