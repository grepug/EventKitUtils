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
            
            for (index, task) in tasks.enumerated() {
                DLCell(using: .swiftUI(movingTo: self, content: {
                    TaskListCell(task: task, recurenceCount: task.repeatingCount) { [unowned self] in
                        em.toggleCompletion(task)
                        reloadList()
                    } presentEditor: { [unowned self] in
                        presentTaskEditor(task: task)
                    }
                }))
                .tag(task.cellTag)
                .child(of: headerTag)
                .backgroundConfiguration(.listGroupedCell())
                .contextMenu(.makeMenu(self.taskMenu(for: task, at: index, isContextMenu: true)).children)
                .swipeTrailingActions(.makeActions(taskMenu(for: task, at: index)).reversed())
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
    func taskMenu(for task: TaskValue, at index: Int = 0, isContextMenu: Bool = false) -> [MBMenu] {
//        if isContextMenu, let kr = task.sortedKeyResults.first {
//            MBButton("v3_task_open_kr".loc, image: kr.displayEmoji.textToImage()!) { [unowned self] in
//                let vc = KeyResultDetail(kr: kr)
//                let nav = vc.navigationControllerWrapped()
//                present(nav, animated: true)
//            }
//        }
        
        if isContextMenu && em.testHasRepeatingTasks(with: task) {
            MBGroup {
                MBButton("查看重复任务", image: .init(systemName: "repeat")) { [unowned self] in
                    guard let vc = makeRepeatingListViewController(title: task.normalizedTitle) else {
                        return
                    }
                    
                    let nav = vc.navigationControllerWrapped()
                    
                    nav.modalPresentationStyle = .popover
                    
                    let indexPath = listView.indexPath(forItemIdentifier: task.cellTag)!
                    nav.popoverPresentationController?.sourceView = listView.cellForItem(at: indexPath)
                    
                    present(nav, animated: true)
                }
            }
        }
        
        MBButton.edit { [unowned self] in
//            presentTaskEditor(taskGroup: taskGroup, at: index)
        }
        
        MBButton.delete { [unowned self] completion in
            if let count = task.repeatingCount, count > 0 {
                presentDeletingTaskGroupAlert {
                    completion(false)
                } deletingThis: { [unowned self] in
                    em.deleteTask(task)
                    completion(true)
                    reloadList()
                } deletingAll: { [unowned self] in
//                    em.deleteTasks(taskGroup.tasks)
                    completion(true)
                    reloadList()
                }
            } else {
                removeTask(task)
                completion(true)
                em.deleteTask(task)
            }
        }
    }
    
    func removeTask(_ task: TaskValue) {
        for (key, _) in groupedTasks {
            groupedTasks[key]?.removeAll { $0.normalizedTitle == task.normalizedTitle }
        }
        
        reload()
    }
    
    func presentDeletingTaskGroupAlert(canceled: @escaping () -> Void, deletingThis: @escaping () -> Void, deletingAll: @escaping () -> Void) {
        presentAlertController(title: "删除所有？",
                               message: "",
                               actions: [
                                .cancel {
                                    canceled()
                                },
                                .init(title: "仅删除当前", style: .destructive) { _ in
                                    deletingThis()
                                },
                                .init(title: "删除所有", style: .destructive) { _ in
                                    deletingAll()
                                }
                               ])
    }
}
