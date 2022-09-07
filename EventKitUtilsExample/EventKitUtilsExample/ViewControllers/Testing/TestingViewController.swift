//
//  TestingViewController.swift
//  EventKitUtilsExample
//
//  Created by Kai Shao on 2022/9/7.
//

import DiffableList
import UIKit
import EventKitUtils

class TestingViewController: DiffableListViewController {
    var em: EventManager {
        .shared
    }
    
    let vm: TestingViweModel = .init()
    
    override var list: DLList {
        DLList {
            DLSection {
                DLCell {
                    DLText("Run")
                }
                .onTapAndDeselect { [weak self] _ in
                    guard let self = self else { return }
                    
                    Task {
                        await self.vm.run()
                        _ = await self.presentAlertController(title: "Succeed", message: nil, actions: [.ok])
                    }
                }
            }
            .tag("0")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        reload()
    }
}

extension TestingViewController {
    
}
