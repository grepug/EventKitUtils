//
//  TaskListViewController.swift
//  
//
//  Created by Kai on 2022/7/20.
//

import DiffableList
import UIKit
import EventKit
import Combine

open class TaskListViewController: DiffableListViewController, TaskHandler, ObservableObject {
    typealias TaskGroupsByState = [TaskKindState: [TaskGroup]]
    
    public var tasks: [TaskGroup] = []
    public var groupedTasks: [TaskKindState: [TaskGroup]] = [:]
    @Published public var segment: SegmentType = .today
    public let config: TaskConfig
    
    lazy var eventStore = EKEventStore()
    var canAccessEventStore = false
    var cancellables = Set<AnyCancellable>()
    
    let reloadingSubject = PassthroughSubject<SegmentType, Never>()
    
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
        
        var isFirst = true
        
        $segment
            .merge(with: reloadingSubject)
            .prepend(segment)
            .flatMap { [unowned self] segment in
                fetchTasksPublisher(for: segment)
            }
            .sink { [weak self] groups in
                guard let self = self else { return }
                
                self.groupedTasks = groups
                self.reload(animating: !isFirst)
                isFirst = false
            }
            .store(in: &cancellables)
    }
    
    open func taskEditorViewController(task: TaskKind, eventStore: EKEventStore) -> TaskEditorViewController {
        .init(task: task, config: config, eventStore: eventStore)
    }
    
    open func fetchNonEventTasksPublisher(for segment: SegmentType) -> AnyPublisher<[TaskKind], Error> {
        Empty<[TaskKind], Error>(completeImmediately: true).eraseToAnyPublisher()
    }
    
    func fetchTasksPublisher(for segment: SegmentType) -> AnyPublisher<TaskGroupsByState, Never> {
        let events: Future<[TaskKind], Never> = Future { [unowned self] promise in
            DispatchQueue.global(qos: .background).async { [unowned self] in
                let tasks = fetchEvents(forSegment: segment).map(\.value)
                promise(.success(tasks))
            }
        }
        
        return events
            .zip(
                fetchNonEventTasksPublisher(for: segment)
                    .catch { error in Empty() }
            )
            .map { [unowned self] events, nonEvents in
                groupTasks(events + nonEvents)
            }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}

extension TaskListViewController {
    func groupTasks(_ tasks: [TaskKind]) -> TaskGroupsByState {
        var dict: TaskGroupsByState = [:]
        var cache: [TaskKindState: [TaskKind]] = [:]
        
        for task in tasks {
            
        }
        
        for (state, tasks) in cache {
            dict[state] = tasks.makeTaskGroups()
        }
        
        for state in TaskKindState.allCases {
            var includingCompleted = false
            
            if segment == .completed {
                includingCompleted = true
            } else if segment == .today && state == .today {
                includingCompleted = true
            }
            
            let filteredTasks = state.filtered(tasks, includingCompleted: includingCompleted)
                .makeTaskGroups()
            
            if segment == .completed {
                
            }
            
            if !filteredTasks.isEmpty {
                dict[state] = filteredTasks
            }
        }
        
        
        return dict
    }
    
    func fetchEvents(forSegment segment: SegmentType) -> [EKEvent] {
        let calendar = eventStore.defaultCalendarForNewEvents!
        let predicate = eventStore.predicateForEvents(withStart: config.eventRequestRange.lowerBound,
                                                      end: config.eventRequestRange.upperBound,
                                                      calendars: [calendar])
        let events = eventStore.events(matching: predicate)
        
        return events
    }
}

extension TaskListViewController {
    func setupNavigationBar() {
        title = segment.text
    }
    
    func presentTaskEditor(task: TaskKind? = nil) {
        var task = task ?? config.createNonEventTask()
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
