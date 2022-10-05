//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/10/4.
//

import DiffableList
import MenuBuilder
import EventKit
import EventKitUtils
import UIKit
import SwiftUI

extension TaskEditorViewController {
    @ListBuilder
    var alarmSection: [DLSection] {
        if let event {
            DLSection {
                DLCell {
                    DLText("提醒")
                }
                .tag("first alarm \(event.taskAlarmType?.title ?? "")")
                .accessories(.popUpMenu(menu: .makeMenu(self.alarmMenu),
                                        value: event.taskAlarmType?.title ?? "无"))
            }
            .tag("alarm section")
        }
    }
}

private extension TaskEditorViewController {
    @MenuBuilder
    var alarmMenu: [MBMenu] {
        MBGroup { [unowned self] in
            MBButton("无", checked: event?.taskAlarmType == nil) { [weak self] in
                guard let self = self, let event = self.event else { return }
                
                event.removeAllTaskAlarms()
                self.reload()
            }
        }
        
        for type in TaskAlarmType.allCases {
            MBButton(type.title, checked: event?.taskAlarmType == type) { [weak self] in
                guard let self = self, let event = self.event else { return }
                
                event.setTaskAlarm(type)
                self.reload()
            }
        }
    }
}
