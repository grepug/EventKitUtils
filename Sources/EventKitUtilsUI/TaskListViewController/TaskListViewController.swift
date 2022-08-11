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
    var fetchingTitle: String?
    
    var cancellables = Set<AnyCancellable>()
    
    private let reloadingSubject = PassthroughSubject<FetchTasksSegmentType, Never>()
    
    var isRepeatingList: Bool {
        fetchingTitle != nil
    }
    
    public init(eventManager: EventManager, initialSegment: FetchTasksSegmentType = .today, fetchingTitle: String? = nil) {
        self.em = eventManager
        self.fetchingTitle = fetchingTitle
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
    
    public override func reload(applyingSnapshot: Bool = true, animating: Bool = true) {
        guard Thread.current == Thread.main else {
            fatalError()
        }
        
        super.reload(applyingSnapshot: applyingSnapshot, animating: animating)
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
            .prepend(segment)
            .map { [unowned self] segment in
                fetchTasksPublisher(for: segment)
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
        if let title = fetchingTitle {
            return .title(title)
        }
        
        return .segment(segment)
    }
    
    func fetchTasksPublisher(for segment: FetchTasksSegmentType) -> AnyPublisher<TaskGroupsByState, Never> {
        Future { [unowned self] promise in
            Task {
                let tasks = await em.fetchTasks(with: fetchingType)
                promise(.success(tasks))
            }
        }
        .map { [unowned self] in groupTasks($0) }
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
            cache[nil] = tasks
            
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
        let countsOfTitleGrouped = tasks.countsOfTitleGrouped
        
        for (state, tasks) in cache {
            dict[state] = tasks
                .sorted(in: state, of: segment)
                .repeatingMerged(withCountsOfTitleGrouped: countsOfTitleGrouped)
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
        let taskObject = em.fetchOrCreateTaskObject(from: task)
        
        let vc = em.makeTaskEditorViewController(task: taskObject) { [unowned self] _ in
            reloadList()
        }
        
        present(vc, animated: true)
    }
}

extension Date {
    var startOfDay: Self {
        Calendar.current.startOfDay(for: self)
    }
}
