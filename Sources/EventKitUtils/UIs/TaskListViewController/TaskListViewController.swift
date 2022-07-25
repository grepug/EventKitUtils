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
    public var tasks: [TaskWrapper] = []
    public var groupedTasks: [TaskKindState: [TaskWrapper]] = [:]
    public var segment: SegmentType = .today
    public let config: TaskConfig
    
    lazy var eventStore = EKEventStore()
    var canAccessEventStore = false
    
    public init(config: TaskConfig) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
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
    
    open func fetchTasks(forSegment segment: SegmentType) -> [TaskWrapper] {
        let calendar = eventStore.defaultCalendarForNewEvents!
        let predicate = eventStore.predicateForEvents(withStart: config.eventRequestRange.lowerBound,
                                                      end: config.eventRequestRange.upperBound,
                                                      calendars: [calendar])
        let events = eventStore.events(matching: predicate)
        
        return events.makeTaskWrappers()
    }
    
    open func taskEditorViewController(task: TaskKind, eventStore: EKEventStore) -> TaskEditorViewController {
        .init(task: task, config: config, eventStore: eventStore)
    }
}

extension TaskListViewController {
    
    func groupTasks(_ tasks: [TaskWrapper]) {
        var dict: [TaskKindState: [TaskWrapper]] = [:]
        
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
    
    func presentTaskEditor(task: TaskKind? = nil) {
        let task = task ?? config.createNonEventTask()
        task.isDateEnabled = true
        
        let vc = taskEditorViewController(task: task, eventStore: eventStore)
        let nav = vc.navigationControllerWrapped()
        
        vc.onDismiss = { [unowned self] in
            reload()
        }
        
        present(nav, animated: true) { [unowned self] in
            saveTask(task)
        }
    }
}
