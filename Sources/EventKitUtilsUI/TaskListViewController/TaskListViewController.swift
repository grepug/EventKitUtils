//
//  TaskListViewController.swift
//  
//
//  Created by Kai on 2022/7/20.
//

import DiffableList
import UIKit
import EventKit
import EventKitUtils
import Combine

open class TaskListViewController: DiffableListViewController, ObservableObject {
    public typealias TaskGroupsByState = [TaskKindState?: [TaskValue]]
    typealias TasksByState = [TaskKindState?: [TaskValue]]
    
    public var groupedTasks: TaskGroupsByState = [:]
    @Published public var segment: FetchTasksSegmentType = .today
    unowned public let em: EventManager
    public var fetchingTitle: String?
    
    public lazy var eventStore = EKEventStore()
    var canAccessEventStore = false
    var cancellables = Set<AnyCancellable>()
    
    private let reloadingSubject = PassthroughSubject<FetchTasksSegmentType, Never>()
    
    var isRepeatingList: Bool {
        fetchingTitle != nil
    }
    
    public init(eventManager: EventManager, fetchingTitle: String? = nil) {
        self.em = eventManager
        self.fetchingTitle = fetchingTitle
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var segmentControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: FetchTasksSegmentType.allCases.map(\.text))
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
            if isRepeatingList {
                if let tasks = self.groupedTasks[nil] {
                    taskSection(tasks, groupedState: nil)
                }
            } else {
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
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        listView.contentInset.bottom = 64
        
        if !isRepeatingList {
            setupCustomToolbar()
        }
        
        setupNavigationBar()
        
        $segment
            .merge(with: reloadingSubject)
            .merge(with: eventsChangedPublisher)
            .prepend(segment)
            .flatMap { [unowned self] segment in
                fetchTasksPublisher(for: segment)
            }
            .sink { [weak self] groups in
                guard let self = self else { return }
                
                self.groupedTasks = groups
                self.reload()
            }
            .store(in: &cancellables)
    }
    
    func taskEditorViewController(task: TaskKind) -> TaskEditorViewController {
        .init(task: task, eventManager: em)
    }
    
    func makeRepeatingListViewController(title: String) -> TaskListViewController {
        .init(eventManager: em, fetchingTitle: title)
    }
}

extension TaskListViewController {
    func reloadList(of segment: FetchTasksSegmentType? = nil) {
        reloadingSubject.send(segment ?? self.segment)
    }
    
    var fetchingType: FetchTasksType {
        if let title = fetchingTitle {
            return .title(title)
        }
        
        return .segment(segment)
    }
    
    func fetchTasksPublisher(for segment: FetchTasksSegmentType) -> AnyPublisher<TaskGroupsByState, Never> {
        Future { [unowned self] promise in
            em.fetchTasksAsync(with: fetchingType) { tasks in
                promise(.success(tasks))
            }
        }
        .map { [unowned self] in groupTasks($0) }
        .receive(on: RunLoop.main)
        .eraseToAnyPublisher()
    }
    
    var eventsChangedPublisher: AnyPublisher<FetchTasksSegmentType, Never> {
        NotificationCenter.default
            .publisher(for: .EKEventStoreChanged)
            .debounce(for: 1, scheduler: RunLoop.current)
            .map { [unowned self] _ in segment }
            .eraseToAnyPublisher()
    }
}

extension TaskListViewController {
    func addToCache(_ state: TaskKindState?, _ task: TaskValue, in cache: inout TasksByState) {
        if cache[state] == nil {
            cache[state] = []
        }
        
        cache[state]!.append(task)
    }
    
    func groupTasks(_ tasks: [TaskValue]) -> TaskGroupsByState {
        var cache: TasksByState = [:]
        let current = Date()
        
        if isRepeatingList {
            cache[nil] = tasks
            
            return cache
        }
        
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
        
        var dict: TaskGroupsByState = [:]
        let tasksGroupedByTitle = tasks.titleGrouped()
        
        for (state, tasks) in cache {
            dict[state] = tasks.repeatingMerged { tasksGroupedByTitle[$0]?.count } 
        }
        
        return dict
    }
}

extension TaskListViewController {
    func setupNavigationBar() {
        if let title = fetchingTitle {
            self.title = title
            navigationItem.rightBarButtonItem = makeDoneButton { [unowned self] in
                presentingViewController?.dismiss(animated: true)
            }
        } else {
            title = segment.text
        }
    }
    
    func presentTaskEditor(task: TaskValue? = nil) {
        var taskObject: TaskKind
        
        if let task = task {
            taskObject = em.taskObject(task)!
        } else {
            taskObject = em.config.createNonEventTask()
        }
        
        taskObject.isDateEnabled = true
        
        let vc = taskEditorViewController(task: taskObject)
        let nav = vc.navigationControllerWrapped()
        
        vc.onDismiss = { [unowned self] in
            reloadList()
        }
        
        present(nav, animated: true) { [unowned self] in
            em.saveTask(taskObject)
        }
    }
}

extension Date {
    var startOfDay: Self {
        Calendar.current.startOfDay(for: self)
    }
}