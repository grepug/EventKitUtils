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
                        em.toggleCompletion(task)
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
                    presentPostponedAlert()
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
    
    func presentPostponedAlert() {
        presentAlertController(title: "v3_task_postpone_alert_title",
                               message: "v3_task_postpone_alert_message",
                               actions: [
                                .cancel,
                                .ok { [unowned self] in
//                                    Task.postpondOverdued()
                                    DispatchQueue.main.async { [unowned self] in
                                        reloadList()
                                    }
                                }
                               ])
    }
}

extension TaskListViewController {
    @MenuBuilder
    func taskMenu(for task: TaskValue, isContextMenu: Bool = false) -> [MBMenu] {
        if isContextMenu, let krId = task.keyResultId {
            MBGroup {
                MBButton("v3_task_open_kr".loc) { [unowned self] in
                    guard let vc = em.config.makeKeyResultDetail!(krId) else {
                        return
                    }
                    
                    present(vc, animated: true)
                }
            }
        }
        
        if isContextMenu && em.testHasRepeatingTasks(with: task) {
            MBGroup {
                MBButton("查看重复任务", image: .init(systemName: "repeat")) { [unowned self] in
                    let vc = TaskListViewController(eventManager: em, fetchingTitle: task.normalizedTitle)
                    
                    vc.modalPresentationStyle = .popover
                    
                    let indexPath = listView.indexPath(forItemIdentifier: task.cellTag)!
                    vc.popoverPresentationController?.sourceView = listView.cellForItem(at: indexPath)
                    
                    present(vc, animated: true)
                }
            }
        }
        
        MBButton.edit { [unowned self] in
            presentTaskEditor(task: task)
        }
        
        MBButton.delete { [unowned self] completion in
            em.handleDeleteTask(task: task, on: self) { [unowned self] in
                completion($0)
                reloadList()
            } removeTask: { [unowned self] in
                removeTask(task)
            }
        }
    }
    
    func removeTask(_ task: TaskValue) {
        for (key, _) in groupedTasks {
            groupedTasks[key]?.removeAll { $0.normalizedTitle == task.normalizedTitle }
        }
        
        reload()
    }
}
