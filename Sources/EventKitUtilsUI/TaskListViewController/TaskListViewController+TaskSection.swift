//
//  TaskListViewController+TaskSection.swift
//  
//
//  Created by Kai on 2022/7/21.
//

import DiffableList
import SwiftUI
import MenuBuilder
import EventKitUtils
import UIKitUtils

extension TaskListViewController {
    @ListBuilder
    func taskSection(_ tasks: [TaskValue], groupedState: TaskKindState?) -> [DLSection] {
        DLSection { [unowned self] in
            let headerTag = self.taskHeaderTag(state: groupedState, count: tasks.count)
            
            if let state = groupedState {
                DLCell(using: .header(state.title))
                    .tag(headerTag)
                    .accessories([
                        .outlineDisclosure(),
                        .label("\(tasks.count)")
                    ])
                    .backgroundConfiguration(.clear())
            }
            
            for task in tasks {
                DLCell(using: .swiftUI(movingTo: self, content: {
                    TaskListCell(task: task) { [unowned self] in
                        await em.toggleCompletion(task)
                        reloadList()
                    } presentEditor: { [unowned self] in
                        presentTaskEditor(task: task)
                    }
                }))
                .tag(task.cellTag)
                .child(of: headerTag)
                .backgroundConfiguration(.listGroupedCell())
                .contextMenu(.makeMenu(self.taskMenu(for: task, isContextMenu: true)).children)
                .swipeTrailingActions(.makeActions(taskMenu(for: task)).reversed())
            }
        }
        .tag(groupedState?.title ?? "tasks")
        .listConfig { config in
            var config = config
            
            if groupedState == .overdued {
                config.footerMode = .supplementary
            }
            
            if groupedState != nil {
                config.headerMode = .firstItemInSection
            }
            
            return config
        }
        .footer(using: groupedState != .overdued ? nil : .swiftUI(movingTo: { [unowned self] in self}, content: {
            HStack {
                Spacer()
                SwiftUI.Button("v3_task_postpone".loc) { [unowned self] in
                    Task {
                        await handlePostpone()
                    }
                }
                .font(.subheadline)
            }
            .padding()
        }))
    }
    
    func taskHeaderTag(state: TaskKindState?, count: Int) -> String? {
        if let state = state {
            return state.title + "\(count)"
        }
        
        return nil
    }
    
    func handlePostpone() async {
        let postponeAction = ActionValue(title: "顺延", style: .default)
        let result = await presentAlertController(title: "v3_task_postpone_alert_title".loc,
                                                  message: "v3_task_postpone_alert_message".loc,
                                                  actions: [postponeAction, .cancel])
        
        if result == postponeAction {
            if let taskValues = groupedTasks[.overdued] {
                print(taskValues)
                
                await em.postpondTasks(taskValues)
            }
        }
    }
    
    func taskMenu(for task: TaskValue, isContextMenu: Bool = false) -> [MBMenu] {
        TaskActionMenuProvider(task: task,
                               eventManager: em,
                               diffableListVC: { [unowned self] in self }) { [unowned self] in
            presentTaskEditor(task: task)
        } manuallyRemoveThisTaskSinceItIsTheLastOne: { [unowned self] in
            removeTask(task)
        } afterDeletion: { [unowned self] in
            reloadList()
        }
        .taskMenu(isContextMenu: isContextMenu)
    }
    
    func removeTask(_ task: TaskValue) {
        for (key, _) in groupedTasks {
            groupedTasks[key]?.removeAll { $0 == task }
        }
        
        DispatchQueue.main.async {
            self.reload()
        }
    }
}
