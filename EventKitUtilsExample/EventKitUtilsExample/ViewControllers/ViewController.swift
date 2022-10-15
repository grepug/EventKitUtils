//
//  ViewController.swift
//  EventKitUtilsExample
//
//  Created by Kai on 2022/7/19.
//

import UIKit
import DiffableList
import EventKit
import EventKitUtils
import SwiftUI

class ViewController: DiffableListViewController {
    lazy var eventStore = EKEventStore()
    var canAccessEventStore = false
    var tasks: [TaskKind] = []
    
    var calendar: EKCalendar {
        eventStore.defaultCalendarForNewEvents!
    }
    
    var baseURL: URL {
        URL(string: "https://okr.vision/a")!
    }
    
    override var list: DLList {
        DLList { [unowned self] in
            if canAccessEventStore {
                DLSection {
                    for task in self.tasks {
                        DLCell(using: .swiftUI(movingTo: self, content: {
                            HStack {
                                Button { [unowned self] in
                                    Task {
                                        try! await EventManager.shared.toggleCompletion(task.value)
                                        reload()
                                    }
                                } label: {
                                    Image(systemName: task.isCompleted ? "checkmark.circle" : "circle")
                                }
                                
                                Text(task.normalizedTitle)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                        }))
                        .tag(task.normalizedID + "\(task.isCompleted.description)")
                    }
                }
                .tag(0)
            } else {
                DLSection {
                    DLCell(using: .swiftUI(movingTo: self, content: {
                        Text("No Access")
                            .padding()
                    }))
                    .tag("no access")
                }
                .tag("no access")
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        title = "Event List"
        navigationController?.navigationBar.prefersLargeTitles = true
        setupNavigationBar()
        
        Task {
            await requestAccess()
        }
    }
}

extension ViewController {
    func setupNavigationBar() {
        navigationItem.rightBarButtonItems = [
            .init(systemItem: .add, primaryAction: .init { [unowned self] _ in
                let event = EKEvent(baseURL: baseURL, eventStore: eventStore)
                
                event.calendar = calendar
                event.normalizedTitle = "Test"
                event.keyResultId = UUID().uuidString
                event.isCompleted = false
                event.normalizedStartDate = Date()
                event.normalizedEndDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
                
                tasks.append(event)
                reload()
                
                try! eventStore.save(event, span: .thisEvent, commit: true)
            })
        ]
    }
    
    func requestAccess() async {
        do {
            let isSuccess = try await eventStore.requestAccess(to: .event)
            canAccessEventStore = isSuccess
            
            let startDate = Calendar.current.startOfDay(for: Date())
            let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate)!
            let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
            let events = eventStore.events(matching: predicate)
                .filter { event in
                    event.url?.host == self.baseURL.host
                }
            
            tasks = events
            
            reload()
        } catch {
            
        }
    }
    
    func saveTask(_ task: TaskKind) {
        if let event = task as? EKEvent {
            try! eventStore.save(event, span: .thisEvent, commit: true)
        }
    }
}
