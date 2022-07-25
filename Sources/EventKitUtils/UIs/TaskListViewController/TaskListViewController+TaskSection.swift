//
//  TaskListViewController+TaskSection.swift
//  
//
//  Created by Kai on 2022/7/21.
//

import DiffableList
import UIKit
import SwiftUI
import MenuBuilder
import UIKitUtils
import EventKit

extension TaskListViewController {
    @ListBuilder
    func taskSection(_ tasks: [TaskWrapper], groupedState: TaskKindState?) -> [DLSection] {
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
                let hidingDate = groupedState == .today
                
                DLCell(using: .swiftUI(movingTo: self, content: {
                    TaskListCell(task: task.first, hidingDate: hidingDate) { [unowned self] in
                        task.first.toggleCompletion()
                        saveTask(task.first)
                        
                        reload()
                    } presentEditor: { [unowned self] in
                        presentTaskEditor(task: task.first)
                    }
                }))
                .tag(task.first.cellTag)
                .child(of: headerTag)
                .backgroundConfiguration(.listGroupedCell())
                .contextMenu(.makeMenu(taskMenu(for: task.first, isContextMenu: true)).children)
                .swipeTrailingActions(.makeActions(taskMenu(for: task.first)).reversed())
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
                SwiftUI.Button("v3_task_postpone") { [unowned self] in
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
                                        reload()
                                    }
                                }
                               ])
    }
}

extension TaskListViewController {
    @MenuBuilder
    func taskMenu(for task: TaskKind, isContextMenu: Bool = false) -> [MBMenu] {
//        if isContextMenu, let kr = task.sortedKeyResults.first {
//            MBButton("v3_task_open_kr".loc, image: kr.displayEmoji.textToImage()!) { [unowned self] in
//                let vc = KeyResultDetail(kr: kr)
//                let nav = vc.navigationControllerWrapped()
//                present(nav, animated: true)
//            }
//        }
        
        MBButton.edit { [unowned self] in
            presentTaskEditor(task: task)
        }
        
        MBButton.delete { [unowned self] in
            if let event = task as? EKEvent {
                try! eventStore.remove(event, span: .thisEvent, commit: true)
            }
            
            reload()
        }
    }
}
