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
    var noDataSection: [DLSection] {
        DLSection { [unowned self] in
            DLCell(using: .swiftUI(movingTo: self, content: {
                Text("no_tasks".loc)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(.top, 256)
            }))
            .backgroundConfiguration(.clear())
            .disableHighlight()
            .tag("none")
        }
        .tag("noData")
    }
    
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
                DLCell(using: .swiftUI(movingTo: self, content: { [unowned self] in
                    #warning("currentStateRepeatingCount not implemented")
                    TaskListCell(task: task,
                                 currentStateRepeatingCount: nil,
                                 hidingRepeatingCount: isRepeatingList) { [weak self] in
                        guard let self else { return }
                        
                        guard await self.toggleCompletionOrPresentError(task) else {
                            return
                        }
                        
                        self.reloadList()
                    } onTap: { [weak self] in
                        self?.handleTaskCellTap(task: task)
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
    
    func handleTaskCellTap(task: TaskValue) {
        if isRepeatingList || task.repeatingCount == nil {
            presentTaskEditor(task: task)
        } else {
            presentRepeatTaskListViewController(task: task)
        }
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
        
        await em.postponeTasks(taskValues)
        reloadList()
    }
}

extension TaskListViewController: TaskHandling {
    public func taskHandling(presentErrorAlertControllerOn withError: Error) -> UIViewController {
        self
    }
}

extension TaskListViewController: TaskActionMenuHandling {
    public func taskActionMenu(presentTaskEditorWith task: TaskValue) {
        presentTaskEditor(task: task)
    }
    
    public func taskActionMenu(manuallyRemoveThisTaskSinceItIsTheLastOneWith task: TaskValue) {
        for (key, _) in groupedTasks {
            groupedTasks[key]?.removeAll { $0 == task }
        }
        
        DispatchQueue.main.async {
            self.reload()
        }
    }
    
    public func taskActionMenu(reloadListWith task: TaskValue) {
        reloadList()
    }
    
    public var hidingOpenKR: Bool {
        false
    }
    
    public var hidingShowingRepeatTasks: Bool {
        isRepeatingList
    }
}
