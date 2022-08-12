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
        let segment: FetchTasksSegmentType = showingTodayTasks ? .today : .incompleted
        
        tasks = await em.fetchTasks(with: .segment(segment))
            .filter { $0.displayInSegment(segment) }
            .sorted(of: segment)
            .repeatingMerged()
            .prefix(3).map { $0 }
    }
}

extension TaskSummaryCard {
    func pushToTaskListViewController() {
        let vc = TaskListViewController(eventManager: em,
                                        initialSegment: showingTodayTasks ? .today : .incompleted)
        
        parentVC.navigationController?.pushViewController(vc, animated: true)
    }
    
    func presentTaskEditor(task: TaskValue? = nil) {
        let task = em.fetchOrCreateTaskObject(from: task)
        
        let vc = em.makeTaskEditorViewController(task: task) { shouldOpenTaskList in
            guard shouldOpenTaskList else {
                return
            }
            
            pushToTaskListViewController()
        }
        
        parentVC.present(vc, animated: true)
    }
}
