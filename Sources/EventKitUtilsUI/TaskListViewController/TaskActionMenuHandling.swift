//
//  TaskActionMenuHandling.swift
//  
//
//  Created by Kai on 2022/8/11.
//

import UIKit
import EventKitUtils
import DiffableList
import MenuBuilder

public protocol TaskActionMenuHandling: DiffableListViewController {
    var em: EventManager { get }
    var hidingOpenKR: Bool { get }
    var hidingShowingRepeatTasks: Bool { get }
    
    func taskActionMenu(presentTaskEditorWith task: TaskValue)
    func taskActionMenu(manuallyRemoveThisTaskSinceItIsTheLastOneWith task: TaskValue)
    func taskActionMenu(reloadListWith task: TaskValue)
}

public extension TaskActionMenuHandling {
    func presentRepeatTaskListViewController(task: TaskValue) {
        let taskList = TaskListViewController(eventManager: em,
                                              mode: .repeatingList(task.repeatingInfo))
        let nav = taskList.navigationControllerWrapped()
        
        nav.modalPresentationStyle = .popover
        
        let indexPath = listView.indexPath(forItemIdentifier: task.cellTag)!
        nav.popoverPresentationController?.sourceView = self.listView.cellForItem(at: indexPath)
        
        present(nav, animated: true)
    }
    
    @MenuBuilder
    func taskMenu(task: TaskValue, isRepeatingList: Bool = false, isContextMenu: Bool = false) -> [MBMenu] {
        if !hidingOpenKR && isContextMenu, let krId = task.keyResultId {
            MBGroup {
                MBButton("action_view_kr".loc) { [weak self] in
                    guard let self = self else { return }
                    
                    guard let krDetail = self.em.uiConfiguration?.makeKeyResultDetailViewController(byID: krId) else {
                        return
                    }
                    
                    self.present(krDetail, animated: true)
                }
            }
        }
        
        if !task.state.isEnded && !hidingShowingRepeatTasks && isContextMenu && task.isRepeating {
            MBGroup {
                MBButton("view_repeat_tasks".loc, image: .init(systemName: "repeat")) { [weak self] in
                    self?.presentRepeatTaskListViewController(task: task)
                }
            }
        }
        
        MBButton.edit { [weak self] in
            self?.taskActionMenu(presentTaskEditorWith: task)
        }
        
        // abortion button, shows when it is not completed
        if task.state != .completed {
            let abortTitle = task.isAborted ? "取消放弃" : "放弃"
            let abortImageName = task.isAborted ? "arrowshape.turn.up.backward.fill" : "xmark"
            
            MBButton(abortTitle, image: .init(systemName: abortImageName), color: .systemYellow, destructive: true) { [weak self] completion in
                guard let self = self else {
                    completion(false)
                    return
                }
                
                Task {
                    let res = await self.em.handleToggleAbortingTask(task: task, on: self, onlyAbortThis: isRepeatingList) { [weak self] in
                        self?.taskActionMenu(manuallyRemoveThisTaskSinceItIsTheLastOneWith: task)
                    }
                    
                    self.taskActionMenu(reloadListWith: task)
                    
                    DispatchQueue.main.async {
                        completion(res)
                    }
                }
            }
        }
        
        MBButton.delete { [weak self] in
            guard let self = self else { return false }
            
            let res = await self.em.handleDeleteTask(task: task, on: self, onlyDeleteThis: isRepeatingList) { [weak self] in
                self?.taskActionMenu(manuallyRemoveThisTaskSinceItIsTheLastOneWith: task)
            }
            
            self.taskActionMenu(reloadListWith: task)
            
            return res
        }
    }
}
