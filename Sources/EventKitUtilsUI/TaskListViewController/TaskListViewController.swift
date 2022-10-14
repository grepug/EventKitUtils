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
import Toast
import MenuBuilder

public class TaskListViewController: DiffableListViewController, ObservableObject {
    var groupedTasks: TasksByState = [:]
    var countsOfStateByRepeatingInfo: CountsOfCompletedTasksByRepeatingInfo = [:]
    
    public enum Mode {
        case list(FetchTasksSegmentType),
             repeatingList(TaskRepeatingInfo),
             keyResultList(KeyResultInfo)
        
        func fetchingType(in segment: FetchTasksSegmentType) -> FetchTasksType {
            switch self {
            case .list: return .segment(segment, keyResultID: nil)
            case .keyResultList(let krInfo): return .segment(segment, keyResultID: krInfo.id)
            case .repeatingList(let info): return .repeatingInfo(info)
            }
        }
        
        var initialSegment: FetchTasksSegmentType {
            switch self {
            case .list(let segment): return segment
            default: return .today
            }
        }
    }
    
    var mode: Mode
    
    @Published var segment: FetchTasksSegmentType
    unowned public let em: EventManager
    var selectedFilterTaskState: TaskListFilterState? {
        didSet {
            Task {
                await handleReloadList()
            }
        }
    }
    
    var cancellables = Set<AnyCancellable>()
    
    private let reloadingSubject = PassthroughSubject<FetchTasksSegmentType, Never>()
    
    var isRepeatingList: Bool {
        switch mode {
        case .repeatingList: return true
        default: return false
        }
    }
    
    var isListEmpty: Bool {
        groupedTasks.isEmpty
    }
    
    public init(eventManager: EventManager, mode: Mode = .list(.today)) {
        self.em = eventManager
        self.mode = mode
        self.segment = mode.initialSegment
        
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
        super.reload(applyingSnapshot: applyingSnapshot, animating: animating, options: options)
        
        // dismiss the repeating list if it's empty
        if isListEmpty, isRepeatingList, let presentingViewController {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                presentingViewController.dismiss(animated: true)
            }
        }
    }
    
    public override func log(message: String) {
        em.uiConfiguration?.log(message)
    }
    
    var isLoading = false
    var hasCollapsedAbortedSection = false
    
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
        button.addAction(.init { [weak self] _ in
            self?.presentTaskEditor()
        }, for: .touchUpInside)
        
        return button
    }()
    
    public override var list: DLList {
        DLList { [unowned self] in
            if self.isListEmpty {
              noDataSection
            } else if isRepeatingList {
                if let tasks = self.groupedTasks[nil] {
                    taskSection(tasks, groupedState: nil)
                }
            } else {
                for state in TaskKindState.allCases {
                    if let tasks = self.groupedTasks[state], !tasks.isEmpty {
                        taskSection(tasks, groupedState: state)
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
            .removeDuplicates()
            .merge(with: reloadingSubject)
            .merge(with: eventsChangedPublisher)
            .throttle(for: 0.3, scheduler: RunLoop.current, latest: false)
            .sink { [weak self] _ in
                guard let self = self else { return }
                    
                self.view.makeToastActivity(.center)
                
                Task {
                    await self.handleReloadList()
                }
            }
            .store(in: &cancellables)
    }
    
    func handleReloadList() async {
        let (groupedTasks, counts) = await Task {
            await em.untilNotPending()
            
            let tasksInfo = await em.fetchTasks(with: mode.fetchingType(in: segment), fetchingKRInfo: true)
            
            let groupedTasks = await groupTasks(tasksInfo.tasks, in: segment, isRepeatingList: isRepeatingList)
            let counts = tasksInfo.completedTaskCounts
            
            assert(groupedTasks.isEmpty ? tasksInfo.tasks.isEmpty : true)
            
            return (groupedTasks, counts)
        }.value
        
        self.groupedTasks = groupedTasks
        self.countsOfStateByRepeatingInfo = counts
        
        // collapse abortion section on first load
        if segment == .completed && !hasCollapsedAbortedSection {
            collapseItem(taskHeaderTag(state: TaskKindState.aborted, count: groupedTasks[.aborted]?.count ?? 0)!)
            hasCollapsedAbortedSection = true
        }
        
        reload()
        view.hideToastActivity()
    }
}

extension TaskListViewController {
    func reloadList(of segment: FetchTasksSegmentType? = nil) {
        reloadingSubject.send(segment ?? self.segment)
    }
    
    var eventsChangedPublisher: AnyPublisher<FetchTasksSegmentType, Never> {
        em.cachesReloaded
            .throttle(for: 1, scheduler: RunLoop.current, latest: false)
            .map { [unowned self] _ in segment }
            .eraseToAnyPublisher()
    }
}

extension TaskListViewController {
    public static let dismissedSubject = PassthroughSubject<Void, Never>()
    
    func setupNavigationBar() {
        navigationItem.rightBarButtonItems = []
        
        if presentingViewController != nil {
            let doneButton: UIBarButtonItem = makeDoneButton { [weak self] in
                self?.presentingViewController?.dismiss(animated: true) {
                    Self.dismissedSubject.send()
                }
            }
            
            navigationItem.rightBarButtonItems?.append(doneButton)
        }
        
        switch mode {
        case .keyResultList(let krInfo):
            self.title = krInfo.title
        case .repeatingList(let info):
            self.title = info.title
            
            let imageName = selectedFilterTaskState == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill"
            let filter = UIBarButtonItem(image: .init(systemName: imageName),
                                         menu: .makeMenu(filterMenu) { [weak self] in
                self?.setupNavigationBar()
            })
            
            navigationItem.rightBarButtonItems?.append(filter)
        case .list:
            self.title = segment.text
        }
    }
    
    @MenuBuilder
    var filterMenu: [MBMenu] {
        MBGroup { [unowned self] in
            MBButton("all".loc, checked: selectedFilterTaskState == nil) { [weak self] in
                self?.selectedFilterTaskState = nil
            }
        }
        
        for item in TaskListFilterState.allCases {
            MBButton(item.title, checked: selectedFilterTaskState == item) { [weak self] in
                self?.selectedFilterTaskState = item
            }
        }
    }
    
    func presentTaskEditor(task: TaskValue? = nil) {
        var keyResultID: String?
        
        if case .keyResultList(let krInfo) = mode {
            keyResultID = krInfo.id
        }
        
        let vc = em.makeTaskEditorViewController(task: task, keyResultId: keyResultID) { [weak self] _ in
            self?.reloadList()
        }
        
        present(vc, animated: true)
    }
}
