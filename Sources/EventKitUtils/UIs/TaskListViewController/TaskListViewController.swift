//
//  TaskListViewController.swift
//  
//
//  Created by Kai on 2022/7/20.
//

import DiffableList
import UIKit
import EventKit

open class TaskListViewController: DiffableListViewController, TaskHandler {
    public var tasks: [TaskKind] = []
    public var groupedTasks: [TaskKindState: [TaskKind]] = [:]
    public var segment: SegmentType = .today
    
    lazy var eventStore = EKEventStore()
    var canAccessEventStore = false
    
    lazy var segmentControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: SegmentType.allCases.map(\.text))
        sc.selectedSegmentIndex = segment.rawValue
        sc.addAction(.init { [unowned self] _ in
            segment = .init(rawValue: sc.selectedSegmentIndex)!
            reload()
            view.endEditing(true)
            setupNavigationBar()
        }, for: .valueChanged)
        
        return sc
    }()
    
    lazy var addButton: UIButton = {
        let button = UIButton()
        let symbolConfiguration = UIImage.SymbolConfiguration(font: UIFont.systemFont(ofSize: 22))
        let image = UIImage(systemName: "plus")?.withConfiguration(symbolConfiguration)
        button.setImage(image, for: .normal)
        button.addAction(.init { [unowned self] _ in
            presentTaskEditor()
        }, for: .touchUpInside)
        
        return button
    }()
    
    open override var list: DLList {
        DLList { [unowned self] in
            switch self.segment {
            case .today, .incompleted:
                for state in TaskKindState.allCases {
                    if let tasks = self.groupedTasks[state] {
                        taskSection(tasks, groupedState: state)
                    }
                }
            case .completed:
                taskSection(tasks, groupedState: nil)
            }
        }
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        listView.contentInset.bottom = 64
        setupCustomToolbar()
        setupNavigationBar()
        reload(animating: false)
    }
    
    open override func reload(applyingSnapshot: Bool = true, animating: Bool = true) {
        tasks = fetchTasks(forSegment: segment)
        groupTasks(tasks)
        
        super.reload(applyingSnapshot: applyingSnapshot, animating: animating)
    }
    
}

extension TaskListViewController {
    open func fetchTasks(forSegment segment: SegmentType) -> [TaskKind] {
        let calendar = eventStore.defaultCalendarForNewEvents!
        let start = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let end = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        let predicate = eventStore.predicateForEvents(withStart: start,
                                                      end: end,
                                                      calendars: [calendar])
        let events = eventStore.events(matching: predicate)

        return events
    }
    
    func groupTasks(_ tasks: [TaskKind]) {
        var dict: [TaskKindState: [TaskKind]] = [:]
        
        for state in TaskKindState.allCases {
            var includingCompleted = false
            
            if segment == .completed {
                includingCompleted = true
            } else if segment == .today && state == .today {
                includingCompleted = true
            }
            
            let filteredTasks = state.filtered(tasks,
                                               includingCompleted: includingCompleted)
            
            if !filteredTasks.isEmpty {
                dict[state] = filteredTasks
            }
        }
        
        
        groupedTasks = dict
    }
}

extension TaskListViewController {
    func setupNavigationBar() {
        title = segment.text
    }
    
    var baseURL: URL {
        URL(string: "https://okr.vision/a")!
    }
    
    func presentTaskEditor(task: TaskKind? = nil) {
        let task = task ?? EKEvent(baseURL: baseURL, eventStore: eventStore)
        task.isDateEnabled = true
        
        let vc = TaskEditorViewController(task: task, eventStore: eventStore)
        let nav = vc.navigationControllerWrapped()
        
        present(nav, animated: true)
    }
}
