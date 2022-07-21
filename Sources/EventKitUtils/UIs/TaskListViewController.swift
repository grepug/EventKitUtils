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
//            presentTaskEditor(.created(of: Self.getRecentLinkedKeyResult()))
        }, for: .touchUpInside)
        
        return button
    }()
    
    open override var list: DLList {
        DLList {
            
        }
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    open override func reload(applyingSnapshot: Bool = true, animating: Bool = true) {
        tasks = fetchTasks(forSegment: segment)
        
        super.reload(applyingSnapshot: applyingSnapshot, animating: animating)
    }
    
        
    open func fetchTasks(forSegment segment: SegmentType) -> [TaskKind] {
        []
    }
}

extension TaskListViewController {
 
}

extension TaskListViewController {
    func setupNavigationBar() {
        title = segment.text
    }
}
