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
    var countsOfStateByRepeatingInfo: CountsOfStateByRepeatingInfo = [:]
    var isListEmpty: Bool = false
    @Published var segment: FetchTasksSegmentType
    unowned public let em: EventManager
    var taskRepeatingInfo: TaskRepeatingInfo?
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
        em.uiConfiguration?.log(message)
    }
    
    var isLoading = false
    
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
        await Task {
            await em.untilNotPending()
            
            let tasksInfo = await em.fetchTasks(with: fetchingType, includingCounts: true)
            
            self.groupedTasks = await groupTasks(tasksInfo.tasks, in: segment, isRepeatingList: isRepeatingList)
            self.isListEmpty = tasksInfo.tasks.isEmpty
            self.countsOfStateByRepeatingInfo = tasksInfo.countsOfStateByRepeatingInfo
        }.value
        
        reload()
        view.hideToastActivity()
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
    
    var eventsChangedPublisher: AnyPublisher<FetchTasksSegmentType, Never> {
        em.cachesReloaded
            .throttle(for: 1, scheduler: RunLoop.current, latest: false)
            .map { [unowned self] _ in segment }
            .eraseToAnyPublisher()
    }
}

extension TaskListViewController {
    static let dismissedSubject = PassthroughSubject<Void, Never>()
    
    func setupNavigationBar() {
        if let title = fetchingTitle {
            self.title = title
            
            let doneButton: UIBarButtonItem = makeDoneButton { [weak self] in
                self?.presentingViewController?.dismiss(animated: true) {
                    Self.dismissedSubject.send()
                }
            }
            
            let imageName = selectedFilterTaskState == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill"
            let filter = UIBarButtonItem(image: .init(systemName: imageName),
                                         menu: .makeMenu(filterMenu) { [weak self] in
                self?.setupNavigationBar()
            })
            
            navigationItem.rightBarButtonItems = [
                doneButton,
                filter
            ]
        } else {
            title = segment.text
        }
    }
    
    @MenuBuilder
    var filterMenu: [MBMenu] {
        MBGroup { [unowned self] in
            MBButton("全部", checked: selectedFilterTaskState == nil) { [weak self] in
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
        let vc = em.makeTaskEditorViewController(task: task) { [weak self] _ in
            self?.reloadList()
        }
        
        present(vc, animated: true)
    }
}
