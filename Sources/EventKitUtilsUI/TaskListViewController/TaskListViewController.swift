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

public class TaskListViewController: DiffableListViewController, ObservableObject {
    typealias TaskGroupsByState = [TaskKindState?: [TaskValue]]
    typealias TasksByState = [TaskKindState?: [TaskValue]]
    
    var groupedTasks: TaskGroupsByState = [:]
    @Published var segment: FetchTasksSegmentType
    unowned let em: EventManager
    var taskRepeatingInfo: TaskRepeatingInfo?
    
    var cancellables = Set<AnyCancellable>()
    
    private let reloadingSubject = PassthroughSubject<FetchTasksSegmentType, Never>()
    
    var isRepeatingList: Bool {
        taskRepeatingInfo != nil
    }
    
    var fetchingTitle: String? {
        if let info = taskRepeatingInfo {
            return info.title
        }
        
        return nil
    }
    
    public init(eventManager: EventManager, initialSegment: FetchTasksSegmentType = .today, repeatingInfo: TaskRepeatingInfo? = nil) {
        self.em = eventManager
        self.taskRepeatingInfo = repeatingInfo
        self.segment = initialSegment
        super.init(nibName: nil, bundle: nil)
        
        hidesBottomBarWhenPushed = true
    }
    
    deinit {
        print("deinit, TaskListViewController")
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func reload(applyingSnapshot: Bool = true, animating: Bool = true, options: Set<DiffableListViewController.ReloadingOption> = []) {
        guard Thread.current == Thread.main else {
            fatalError()
        }
        
        super.reload(applyingSnapshot: applyingSnapshot, animating: animating, options: options)
    }
    
    public override func log(message: String) {
        em.config.log?(message)
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
    
    public override var list: DLList {
        DLList { [unowned self] in
            if isRepeatingList {
                if let tasks = self.groupedTasks[nil] {
                    taskSection(tasks, groupedState: nil)
                }
            } else {
                switch self.segment {
                case .today, .incompleted:
                    for state in TaskKindState.allCases {
                        if let tasks = self.groupedTasks[state], !tasks.isEmpty {
                            taskSection(tasks, groupedState: state)
                        }
                    }
                case .completed:
                    if let tasks = self.groupedTasks[nil], !tasks.isEmpty {
                        taskSection(tasks, groupedState: nil)
                    }
                }
            }
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        listView.contentInset.bottom = 64
        
        if !isRepeatingList {
            setupCustomToolbar()
        }
        
        setupNavigationBar()
        
        $segment
            .merge(with: reloadingSubject)
            .merge(with: eventsChangedPublisher)
            .debounce(for: 0.1, scheduler: RunLoop.main)
            .dropFirst(2)
            .prepend(segment)
            .compactMap { [weak self] segment in
                self?.fetchTasksPublisher(for: segment)
            }
            .switchToLatest()
            .receive(on: RunLoop.main)
            .sink { [weak self] groups in
                guard let self = self else { return }
                
                self.groupedTasks = groups
                self.reload()
            }
            .store(in: &cancellables)
    }
}

extension TaskListViewController {
    func reloadList(of segment: FetchTasksSegmentType? = nil) {
        reloadingSubject.send(segment ?? self.segment)
    }
    
    var fetchingType: FetchTasksType {
        if let info = taskRepeatingInfo {
            return .repeatingInfo(info)
        }
        
        return .segment(segment)
    }
    
    func fetchTasksPublisher(for segment: FetchTasksSegmentType) -> AnyPublisher<TaskGroupsByState, Never> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.success([]))
                return
            }
            
            Task {
                let tasks = await self.em.fetchTasks(with: self.fetchingType)
                promise(.success(tasks))
            }
        }
        .compactMap { [weak self] in self?.groupTasks($0) }
        .eraseToAnyPublisher()
    }
    
    var eventsChangedPublisher: AnyPublisher<FetchTasksSegmentType, Never> {
        em.cachesReloaded
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
        
        if isRepeatingList {
            cache[nil] = tasks.sorted()
            
            return cache
        }
        
        if segment == .completed {
            cache[nil] = tasks.filter { $0.isCompleted }
        } else {
            for task in tasks {
                if task.displayInSegment(segment) {
                    addToCache(task.state, task, in: &cache)
                }
            }
        }
        
        var dict: TaskGroupsByState = [:]
        let countsOfTitleGrouped = tasks.countsOfRepeatingGrouped
        
        for (state, tasks) in cache {
            dict[state] = tasks
                .sorted(in: state, of: segment)
                .repeatingMerged(withCountsOfTitleGrouped: countsOfTitleGrouped)
        }
        
        return dict
    }
}

extension TaskListViewController {
    static let dismissedSubject = PassthroughSubject<Void, Never>()
    
    func setupNavigationBar() {
        if let title = fetchingTitle {
            self.title = title
            navigationItem.rightBarButtonItem = makeDoneButton { [weak self] in
                self?.presentingViewController?.dismiss(animated: true) {
                    Self.dismissedSubject.send()
                }
            }
        } else {
            title = segment.text
        }
    }
    
    func presentTaskEditor(task: TaskValue? = nil) {
        let taskObject = em.fetchOrCreateTaskObject(from: task)
        
        let vc = em.makeTaskEditorViewController(task: taskObject) { [weak self] _ in
            self?.reloadList()
        }
        
        present(vc, animated: true)
    }
}

extension Date {
    var startOfDay: Self {
        Calendar.current.startOfDay(for: self)
    }
}
