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
    public typealias TaskGroupsByState = [TaskKindState?: [TaskGroup]]
    typealias TasksByState = [TaskKindState?: [TaskKind]]
    
    public var groupedTasks: TaskGroupsByState = [:]
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
            reloadList()
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
                if let tasks = self.groupedTasks[nil] {
                    taskSection(tasks, groupedState: nil)
                }
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
    
    open func fetchNonEventTasksPublisher(for segment: SegmentType) -> AnyPublisher<[TaskValue], Error> {
        Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
}

extension TaskListViewController {
    func reloadList(of segment: SegmentType? = nil) {
        reloadingSubject.send(segment ?? self.segment)
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
            .map { $0 + $1 }
            .map { [unowned self] in groupTasks($0) }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}

extension TaskListViewController {
    func addToCache(_ state: TaskKindState?, _ task: TaskKind, in cache: inout TasksByState) {
        if cache[state] == nil {
            cache[state] = []
        }
        
        cache[state]!.append(task)
    }
    
    func groupTasks(_ tasks: [TaskKind]) -> TaskGroupsByState {
        var dict: TaskGroupsByState = [:]
        var cache: TasksByState = [:]
        let current = Date()
        
        if segment == .completed {
            cache[nil] = tasks.filter { $0.isCompleted }
        } else {
            for task in tasks {
                if segment == .incompleted && task.isCompleted {
                    continue
                }
                
                if task.isDateEnabled, let endDate = task.normalizedEndDate {
                    /// 兼容没有开始时间的情况
                    if task.normalizedStartDate == nil || task.isAllDay {
                        if endDate.startOfDay == current.startOfDay {
                            addToCache(.today, task, in: &cache)
                        } else if endDate.startOfDay < current.startOfDay {
                            addToCache(.overdued, task, in: &cache)
                        } else {
                            addToCache(.afterToday, task, in: &cache)
                        }
                    } else {
                        /// 包含今天，则为今天
                        if let range = task.dateRange, range.contains(current) {
                            addToCache(.today, task, in: &cache)
                        } else if endDate < current {
                            if !task.isCompleted {
                                addToCache(.overdued, task, in: &cache)
                            }
                        } else {
                            addToCache(.afterToday, task, in: &cache)
                        }
                    }
                } else {
                    addToCache(.unscheduled, task, in: &cache)
                }
            }
        }
        
        for (state, tasks) in cache {
            dict[state] = tasks.makeTaskGroups()
        }
        
        return dict
    }
    
    func fetchEvents(forSegment segment: SegmentType) -> [EKEvent] {
        let calendar = eventStore.defaultCalendarForNewEvents!
        let predicate = eventStore.predicateForEvents(withStart: config.eventRequestRange.lowerBound,
                                                      end: config.eventRequestRange.upperBound,
                                                      calendars: [calendar])
        
        let events = eventStore.events(matching: predicate)
            .filter { [unowned self] in $0.url?.host == config.eventBaseURL.host }
        
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
            reloadList()
        }
        
        present(nav, animated: true) { [unowned self] in
            saveTask(task)
        }
    }
}
