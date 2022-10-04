//
//  TaskEditorViewController+CalendarSyncSections.swift
//  
//
//  Created by Kai Shao on 2022/9/22.
//

import DiffableList
import MenuBuilder
import EventKit
import EventKitUtils
import UIKit
import SwiftUI

extension TaskEditorViewController {
    @ListBuilder
    var calendarLinkingSection: [DLSection] {
        if let event {
            if event.isDetached {
                DLSection { [unowned self] in
                    DLCell(using: .swiftUI(movingTo: self, content: {
                        VStack(spacing: 8) {
                            HStack {
                                Text("无法编辑重复规则")
                                    .foregroundColor(.secondary)
                                
                                Button {
                                    
                                } label: {
                                    Image(systemName: "questionmark.circle")
                                }
                            }
                            Button { [weak self] in
                                self?.presentEventEditor()
                            } label: {
                                Text("编辑日历日程")
                                    .font(.subheadline)
                            }
                        }
                    }))
                    .tag("detached")
                    .backgroundConfiguration(.clear())
                }
                .tag("detached event")
            } else {
                calendarSyncSettingsSection(event: event)
            }
        } else {
            calendarSyncEnablingSection
        }
    }
    
    @MenuBuilder
    private var repeatingMenu: [MBMenu] {
        for item in TaskRecurrenceRule.allCases.filter({ $0 != .custom }) {
            MBButton(item.title, checked: event?.taskRecurrenceRule == item) { [weak self] in
                guard let self, let event = self.event else { return }
                
                guard let recurrenceEndDate = event.recurrenceEndDate ?? event.normalizedStartDate?.nextWeek else {
                    return
                }
                
                event.setTaskRecurrenceRule(item, end: .init(end: recurrenceEndDate))
                self.reload()
            }
        }
        
        MBGroup { [unowned self] in
            MBButton(TaskRecurrenceRule.custom.title, checked: event?.taskRecurrenceRule == .custom) { [weak self] in
                guard let self else { return }
                
                self.presentEventEditor { vc in
                    vc.view.makeToast("自定义重复规则需要在日历日程编辑页设置", position: .center)
                }
                
                self.reload()
            }
        }
    }
    
    @ListBuilder
    private var editingHeader: [DLCell] {
        DLCell(using: .header(" "))
            .accessories([
                .labelButton(title: "编辑日历日程", action: { [weak self] button in
                    self?.presentEventEditor()
                })
            ])
            .tag("calendarHeader")
    }
    
    @ListBuilder
    private func calendarSyncSettingsSection(event: EKEvent) -> [DLSection] {
        DLSection { [unowned self] in
            editingHeader
            
            DLCell {
                DLText("重复")
            }
            .tag("repeat \(event.taskRecurrenceRule.title) \(forceReloadFlag)")
            .accessories(.popUpMenu(menu: .makeMenu(self.repeatingMenu),
                                    value: event.taskRecurrenceRule.title))
            
            if event.taskRecurrenceRule != .never {
                DLCell(using: .datePicker(labelText: "结束重复",
                                          date: event.recurrenceEndDate!,
                                          valueDidChange: { [weak self] date in
                    guard let self, let event = self.event else { return }
                    
                    event.setTaskRecurrenceRule(event.taskRecurrenceRule, end: .init(end: date))
                    #if !targetEnvironment(macCatalyst)
                    self.reload(animating: false)
                    #endif
                }))
                .tag("repeat end \(self.event?.recurrenceEndDate?.description ?? "")")
            }
        }
        .tag("repeating")
        .firstCellAsHeader()
    }
    
    @ListBuilder
    private var calendarSyncEnablingSection: [DLSection] {
        DLSection { [unowned self] in
            DLCell {
                DLText("任务重复、提醒".loc)
                DLText("此功能需开启日历同步".loc)
                    .secondary()
                    .color(.secondaryLabel)
            }
            .tag("calendar \(isEvent) \(forceReloadFlag)")
            .accessories([
                .label("开启日历同步", color: .accentColor),
            ])
            .onTapAndDeselect { [weak self] _ in
                guard let self = self else { return }
                
                Task {
                    await self.convertToEvent()
                    self.reload()
                }
            }
        }
        .tag("4")
    }
}

extension TaskRecurrenceRule {
    var title: String {
        switch self {
        case .never: return "永不"
        case .daily: return "每天"
        case .everyWorkDay: return "每个工作日"
        case .everyWeekendDay: return "每个周末"
        case .weekly: return "每周"
        case .everyTwoWeek: return "每两周"
        case .monthly: return "每月"
        case .yearly: return "每年"
        case .custom: return "自定义"
        }
    }
}
