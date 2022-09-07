//
//  TaskSummaryCard.swift
//  EventKitUtilsExample
//
//  Created by Kai on 2022/8/4.
//

import DiffableList
import EventKitUtils
import EventKitUtilsUI

class TaskSummaryCardList: DiffableListViewController {
    var tasks: [TaskValue] = []
    var em: EventManager {
        .shared
    }
    
    override var list: DLList {
        DLList {
            DLSection { [unowned self] in
                DLCell(using: .swiftUI(movingTo: self, content: { [unowned self] in
                    TaskSummaryCard(vm: .init(eventManager: .shared, parentVC: self))
                }))
                .tag("tasks")
            }
            .tag("0")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Summary"
        setTopPadding()
        reload(animating: false)
    }
}
