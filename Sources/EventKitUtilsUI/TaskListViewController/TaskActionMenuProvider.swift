//
//  TaskActionMenuProvider.swift
//  
//
//  Created by Kai on 2022/8/11.
//

import UIKit
import EventKitUtils
import DiffableList
import MenuBuilder

public struct TaskActionMenuProvider {
    public init(task: TaskValue, eventManager: EventManager, diffableListVC: @escaping () -> DiffableListViewController?, hidingOpenKR: Bool = false, hidingShowingRepeatTasks: Bool = false,  presentTaskEditor: @escaping () -> Void, manuallyRemoveThisTaskSinceItIsTheLastOne removeTask: (() -> Void)? = nil, afterDeletion: (() -> Void)? = nil) {
        self.task = task
        self.eventManager = eventManager
        self.diffableListVC = diffableListVC
        self.hidingOpenKR = hidingOpenKR
        self.hidingShowingRepeatTasks = hidingShowingRepeatTasks
        self.presentTaskEditor = presentTaskEditor
        self.removeTask = removeTask
        self.afterDeletion = afterDeletion
    }
    
    var task: TaskValue
    var eventManager: EventManager
    var diffableListVC: () -> DiffableListViewController?
    var hidingOpenKR = false
    var hidingShowingRepeatTasks = false
    var presentTaskEditor: () -> Void
    var removeTask: (() -> Void)?
    var afterDeletion: (() -> Void)?
    
    var em: EventManager {
        eventManager
    }
    
    var vc: DiffableListViewController? {
        diffableListVC()
    }
    
    var listView: DiffableListView? {
        vc?.listView
    }
    
    var repeatingInfo: TaskRepeatingInfo {
        task.repeatingInfo
    }
    
    @MenuBuilder
    public func taskMenu(isContextMenu: Bool = false) -> [MBMenu] {
        if !hidingOpenKR && isContextMenu, let krId = task.keyResultId {
            MBGroup {
                MBButton("action_view_kr".loc) {
                    guard let krDetail = em.uiConfiguration?.makeKeyResultDetail(byID: krId) else {
                        return
                    }
                    
                    vc?.present(krDetail, animated: true)
                }
            }
        }
        
//        em.testHasRepeatingTasks(with: repeatingInfo)
        if !hidingShowingRepeatTasks && isContextMenu {
            MBGroup {
                MBButton("view_repeat_tasks".loc, image: .init(systemName: "repeat")) {
                    guard let listView = listView else {
                        return
                    }
                    
                    let taskList = TaskListViewController(eventManager: em,
                                                          repeatingInfo: repeatingInfo)
                    let nav = taskList.navigationControllerWrapped()
                    
                    nav.modalPresentationStyle = .popover
                    
                    let indexPath = listView.indexPath(forItemIdentifier: task.cellTag)!
                    nav.popoverPresentationController?.sourceView = listView.cellForItem(at: indexPath)
                    
                    vc?.present(nav, animated: true)
                }
            }
        }
        
        MBButton.edit {
            presentTaskEditor()
        }
        
        MBButton.delete {
            guard let vc = vc else {
                return false
            }
            
            let res = await em.handleDeleteTask(task: task, on: vc) {
                removeTask?()
            }
            
            afterDeletion?()
            
            return res
        }
    }
}
