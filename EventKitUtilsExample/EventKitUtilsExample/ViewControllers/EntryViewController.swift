//
//  EntryViewController.swift
//  EventKitUtilsExample
//
//  Created by Kai on 2022/7/21.
//

import DiffableList
import UIKit
import UIKitUtils
import EventKitUtils
import EventKitUtilsUI
import StorageProvider
import CoreData

class EntryViewController: DiffableListViewController {
    override var list: DLList {
        DLList { [unowned self] in
            DLSection {
                DLCell {
                    DLText("TaskListViewController")
                }
                .tag("taskList")
                .accessories([.disclosureIndicator()])
                .onTapAndDeselect { [unowned self] _ in
                    let vc = TaskListViewController(eventManager: .shared)
                    push(vc)
                }
                
                DLCell {
                    DLText("EventSettings")
                }
                .tag("eventSettings")
                .accessories([.disclosureIndicator()])
                .onTapAndDeselect { [unowned self] _ in
                    let vc = EventSettingsViewController(eventManager: .shared)
                    push(vc)
                }
                
                DLCell {
                    DLText("TaskSummaryCard")
                }
                .tag("taskSummaryCard")
                .accessories([.disclosureIndicator()])
                .onTapAndDeselect { [unowned self] _ in
                    let vc = TaskSummaryCardList()
                    push(vc)
                }
                
            }
            .tag("0")
            
            DLSection {
                DLCell {
                    DLText("Test")
                }
                .tag("test")
                .onTapAndDeselect { [weak self] _ in
                    self?.push(TestingViewController())
                }
            }
            .tag("1")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Entry"
        navigationController?.navigationBar.prefersLargeTitles = true
        setTopPadding()
        
        reload()
    }
}


extension EventManager {
    static let shared = EventManager(configuration: MyEventConfiguration(),
                                     uiConfiguration: MyEventUIConfiguration(),
                                     cacheHandlers: MyCacheHandlers())
}

extension EventManager {
    struct MyCacheHandlers: CacheHandlers {
        var orderNSExpression: NSExpression {
            .init(forKeyPath: \CachedTask.order_)
        }
        
        var stateNSExpression: NSExpression {
            .init(forKeyPath: \CachedTask.state_)
        }
        
        var persistentContainer: NSPersistentContainer {
            StorageProvider.shared.persistentContainer
        }
        
        var cachedTaskKind: CachedTaskKind.Type {
            CachedTask.self
        }
        
        var abortionDateNSExpression: NSExpression {
            .init(forKeyPath: \CachedTask.abortionDate)
        }
    }
    
    struct MyEventConfiguration: EventConfiguration {
        func eventRequestDateInterval() async -> DateInterval? {
            nil
        }
        
        func fetchNonEventTaskCount(withRepeatingInfo repeatingInfo: EventKitUtils.TaskRepeatingInfo) async -> Int? {
            nil
        }
        
        func fetchNonEventTaskCount(withKeyResultID keyResultID: String) async -> Int {
            0
        }
        
        func fetchNonEventTasks(type: EventKitUtils.FetchTasksType, includingCounts: Bool) async -> EventKitUtils.FetchedTaskResult? {
            nil
        }
        
        func fetchNonEventTask(byID id: String) async -> EventKitUtils.TaskValue? {
            nil
        }
        
        func saveNonEventTask(_ taskValue: EventKitUtils.TaskValue) async {
            
        }
        
        func deleteNonEventTask(byID id: String) async {
            
        }
        
        func fetchNonEventTasks(type: EventKitUtils.FetchTasksType) async -> [EventKitUtils.TaskValue] {
            []
        }
        
        var eventBaseURL: URL {
            .init(string: "https://okr.vision/a")!
        }
        
        var appGroupIdentifier: String? {
            nil
        }
        
        var maxNonProLimit: Int? {
            nil
        }
        
        var eventRequestRange: Range<Date> {
            let current = Date()
            let start = Calendar.current.date(byAdding: .year, value: -1, to: current)!
            let end = Calendar.current.date(byAdding: .year, value: 1, to: current)!
            
            return start..<end
        }
        
        func fetchTaskCount(with repeatingInfo: EventKitUtils.TaskRepeatingInfo) async -> Int? {
            nil
        }
        
        func createNonEventTask() async -> EventKitUtils.TaskValue {
            let context = Mission.newBackgroundContext()
            
            return await withCheckedContinuation { continuation in
                let mission = Mission.initWithViewContext(context)
                continuation.resume(returning: mission.value)
            }
        }
        
        func fetchTask(byID id: String, creating: Bool) async -> EventKitUtils.TaskValue? {
            nil
        }
        
        func saveTask(_ taskValue: EventKitUtils.TaskValue) async {
            
        }
        
        func deleteTask(byID id: String) async {
            
        }
        
        func fetchKeyResultInfo(byID id: String) async -> EventKitUtils.KeyResultInfo? {
            nil
        }
        
        
    }
    
    struct MyEventUIConfiguration: EventUIConfiguration {
        func presentNonProErrorAlert(on vc: UIViewController) {
            
        }
        
        func makeKeyResultSelectorViewController(completion: @escaping (String) -> Void) -> UIViewController {
            fatalError()
        }
        
        func makeKeyResultDetailViewController(byID id: String) -> UIViewController? {
            nil
        }
        
        func log(_ message: String) {
            
        }
        
        func logError(_ error: Error) {
            
        }
    }
}
