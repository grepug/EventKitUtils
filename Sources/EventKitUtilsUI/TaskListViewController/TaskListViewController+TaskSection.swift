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
                    TaskListCell(task: task) { [weak self] in
                        guard let self = self else { return }
                        
                        await self.em.toggleCompletion(task)
                        self.reloadList()
                    } presentEditor: { [weak self] in
                        Task {
                            await self?.presentTaskEditor(task: task)
                        }
                    }
                }))
                .tag(task.cellTag)
                .child(of: headerTag)
                .backgroundConfiguration(.listGroupedCell())
                .contextMenu(.makeMenu(self.taskMenu(task: task, isContextMenu: true)).children)
                .swipeTrailingActions(.makeActions(taskMenu(task: task)).reversed())
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
        let postponeAction = ActionValue(title: "v3_task_postpone".loc, style: .default)
        let result = await presentAlertController(title: "v3_task_postpone_alert_title".loc,
                                                  message: "v3_task_postpone_alert_message".loc,
                                                  actions: [postponeAction, .cancel])
        
        guard result == postponeAction,
              let taskValues = groupedTasks[.overdued] else {
            return
        }
        
        await em.postpondTasks(taskValues)
        reloadList()
    }
}

extension TaskListViewController: TaskActionMenuHandling {
    public func taskActionMenu(presentTaskEditorWith task: TaskValue) {
        Task {
            await presentTaskEditor(task: task)
        }
    }
    
    public func taskActionMenu(manuallyRemoveThisTaskSinceItIsTheLastOneWith task: TaskValue) {
        for (key, _) in groupedTasks {
            groupedTasks[key]?.removeAll { $0 == task }
        }
        
        DispatchQueue.main.async {
            self.reload()
        }
    }
    
    public func taskActionMenu(afterDeletionWith task: TaskValue) {
        reloadList()
    }
    
    public var hidingOpenKR: Bool {
        false
    }
    
    public var hidingShowingRepeatTasks: Bool {
        isRepeatingList
    }
}
