//
//  TaskSummaryCard.swift
//  EventKitUtilsExample
//
//  Created by Kai on 2022/8/4.
//

import DiffableList
import EventKitUtils
import EventKitUtilsUI

class TaskSummaryCardList: DiffableListViewController {
    var tasks: [TaskValue] = []
    var em: EventManager {
        .shared
    }
    
    override var list: DLList {
        DLList {
            DLSection { [unowned self] in
                DLCell(using: .swiftUI(movingTo: self, content: {
                    TaskSummaryCard(tasks: self.tasks) { showingTodayTasks in
                        /// show more button
                        
                    } createTask: { [unowned self] in
                        presentTaskEditor()
                    } presentTaskEdtor: { [unowned self] task in
                        let vc = TaskEditorViewController(task: task, eventManager: em)
                        present(vc, animated: true)
                    }
                }))
                .tag("tasks \(tasks.description)")
            }
            .tag("0")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reloadList()
    }
    
    func reloadList() {
        Task {
            let tasks = await em.fetchTasks(with: .segment(.today))
            let tasksGroupedByTitle = tasks.titleGrouped()
            
            self.tasks = tasks
                .repeatingMerged(repeatingCount: { tasksGroupedByTitle[$0]?.count })
                .prefix(3).map { $0 }
            
            reload(animating: false)
        }
    }
}

extension TaskSummaryCardList {
    func presentTaskEditor() {
        let task = em.config.createNonEventTask()
        let vc = TaskEditorViewController(task: task, eventManager: em)
        present(vc, animated: true)
    }
}
