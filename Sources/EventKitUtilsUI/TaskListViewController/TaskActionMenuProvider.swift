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
    public init(task: TaskValue, eventManager: EventManager, diffableListVC: DiffableListViewController, hidingOpenKR: Bool = false, presentTaskEditor: @escaping () -> Void, removeTask: (() -> Void)? = nil) {
        self.task = task
        self.eventManager = eventManager
        self.diffableListVC = diffableListVC
        self.hidingOpenKR = hidingOpenKR
        self.presentTaskEditor = presentTaskEditor
        self.removeTask = removeTask
    }
    
    var task: TaskValue
    var eventManager: EventManager
    var diffableListVC: DiffableListViewController
    var hidingOpenKR = false
    var presentTaskEditor: () -> Void
    var removeTask: (() -> Void)?
    
    var em: EventManager {
        eventManager
    }
    
    var vc: DiffableListViewController {
        diffableListVC
    }
    
    var listView: DiffableListView {
        vc.listView
    }
    
    var repeatingInfo: TaskRepeatingInfo {
        task.repeatingInfo
    }
    
    @MenuBuilder
    public func taskMenu(isContextMenu: Bool = false) -> [MBMenu] {
        if !hidingOpenKR && isContextMenu, let krId = task.keyResultId {
            MBGroup {
                MBButton("v3_task_open_kr".loc) {
                    guard let krDetail = em.config.makeKeyResultDetail!(krId) else {
                        return
                    }
                    
                    vc.present(krDetail, animated: true)
                }
            }
        }
        
        if isContextMenu && em.testHasRepeatingTasks(with: repeatingInfo) {
            MBGroup {
                MBButton("查看重复任务", image: .init(systemName: "repeat")) {
                    let taskList = TaskListViewController(eventManager: em,
                                                          repeatingInfo: repeatingInfo)
                    let nav = taskList.navigationControllerWrapped()
                    
                    nav.modalPresentationStyle = .popover
                    
                    let indexPath = listView.indexPath(forItemIdentifier: task.cellTag)!
                    nav.popoverPresentationController?.sourceView = listView.cellForItem(at: indexPath)
                    
                    vc.present(nav, animated: true)
                }
            }
        }
        
        MBButton.edit {
            presentTaskEditor()
        }
        
        MBButton.delete {
            await em.handleDeleteTask(task: task, on: vc) {
                removeTask?()
            }
        }
    }
}
