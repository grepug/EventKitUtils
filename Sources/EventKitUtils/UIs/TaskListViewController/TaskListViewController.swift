//
//  TaskListViewController.swift
//  
//
//  Created by Kai on 2022/7/20.
//

import DiffableList
import UIKit
import EventKit

open class TaskListViewController: DiffableListViewController {
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
            switch segment {
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
        
        super.reload(applyingSnapshot: applyingSnapshot, animating: animating)
    }
    
}

extension TaskListViewController {
    open func fetchTasks(forSegment segment: SegmentType) -> [TaskKind] {
        []
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
        let vc = TaskEditorViewController(task: task)
        let nav = vc.navigationControllerWrapped()
        
        present(nav, animated: true)
    }
}
