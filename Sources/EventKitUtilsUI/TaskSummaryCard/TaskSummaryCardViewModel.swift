//
//  TaskSummaryCardViewModel.swift
//  
//
//  Created by Kai Shao on 2022/9/6.
//

import UIKit
import EventKitUtils
import SwiftUI
import Combine

@MainActor
public class TaskSummaryCardViewModel: ObservableObject {
    unowned public let em: EventManager
    unowned let parentVC: UIViewController
    
    @Published var tasks: [TaskValue] = []
    @Published var counts: CountsOfCompletedTasksByRepeatingInfo = [:]
    @Published var checkedTaskIds: Set<String> = []
    @Published var showingTodayTasks: Bool = UserDefaults.standard.bool(forKey: "showingTodayTasks") {
        didSet {
            UserDefaults.standard.set(showingTodayTasks, forKey: "showingTodayTasks")
        }
    }
    
    let reloadSubject = PassthroughSubject<Void, Never>()
    
    var cancellables = Set<AnyCancellable>()
    
    deinit {
        print("deinit TaskSummaryCard vm")
    }
    
    public init(eventManager em: EventManager, parentVC: UIViewController) {
        self.em = em
        self.parentVC = parentVC
        
        reloadSubject
            .merge(with: em.cachesReloaded)
            .merge(with: TaskListViewController.dismissedSubject)
            .debounce(for: 1, scheduler: RunLoop.main)
            .prepend(())
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                Task {
                    await self.reload()
                }
            }
            .store(in: &cancellables)
    }
}

extension TaskSummaryCardViewModel: TaskHandling {
    public func taskHandling(presentErrorAlertControllerOn withError: Error) -> UIViewController {
        parentVC
    }
    
    func checkTask(_ task: TaskValue) async {
        checkedTaskIds.insert(task.normalizedID)
        
        try! await Task.sleep(nanoseconds: 300_000_000)
        
        for taskID in checkedTaskIds {
            if let task = tasks.first(where: { $0.normalizedID == taskID }) {
                guard await toggleCompletionOrPresentError(task) else {
                    return
                }
            }
        }
        
        checkedTaskIds.removeAll()
        await reload()
    }
    
    func removeTask(_ task: TaskValue) {
        Task {
            await em.handleDeleteTask(task: task, on: parentVC) { [weak self] in
                self?.tasks.removeAll { $0.normalizedID == task.normalizedID }
            }
            
            await reload()
        }
    }
    
    func relativeDateColor(_ task: TaskKind) -> Color {
        let days = task.normalizedEndDate.map { Date().days(to: $0, includingLastDay: false) } ?? 1
        
        if days == 0 {
            return .green
        } else if days < 0 {
            return .red
        }
        
        return .secondary
    }
    
    func presentRepeatTasks(for task: TaskValue) {
        let vc = TaskListViewController(eventManager: em,
                                        mode: .repeatingList(task.repeatingInfo))
        parentVC.present(vc, animated: true)
    }
}

extension TaskSummaryCardViewModel {
    func presentRepeatTaskListViewController(task: TaskValue) {
        let taskList = TaskListViewController(eventManager: em,
                                              mode: .repeatingList(task.repeatingInfo))
        let nav = taskList.navigationControllerWrapped()
        
        nav.modalPresentationStyle = .formSheet
        
        parentVC.present(nav, animated: true)
    }
}

extension TaskSummaryCardViewModel {
    @MainActor
    func reload() async {
        let segment: FetchTasksSegmentType = showingTodayTasks ? .today : .incompleted
        
        let result = await em.fetchTasks(with: .segment(segment, keyResultID: nil))
        let tasks = result
            .tasks
            .filter { $0.displayInSegment(segment) }
            .sorted(of: segment)
            .repeatingMerged()
            .prefix(3).map { $0 }
        
        
        self.tasks = tasks
        self.counts = result.completedTaskCounts
    }
}

extension TaskSummaryCardViewModel {
    func pushToTaskListViewController() {
        let vc = TaskListViewController(eventManager: em,
                                        mode: .list(showingTodayTasks ? .today : .incompleted))
        
        parentVC.navigationController?.pushViewController(vc, animated: true)
    }
    
    @MainActor
    func presentTaskEditor(task: TaskValue? = nil) async {
        let vc = em.makeTaskEditorViewController(task: task) { [weak self] shouldOpenTaskList in
            guard shouldOpenTaskList else {
                return
            }
            
            self?.pushToTaskListViewController()
        }
        
        parentVC.present(vc, animated: true)
    }
}
