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
                detachedSection
            } else {
                calendarSyncSettingsSection(event: event)
            }
        } else {
            calendarSyncEnablingSection
        }
    }
    
    @ListBuilder
    private var detachedSection: [DLSection] {
        DLSection { [unowned self] in
            DLCell(using: .swiftUI(movingTo: self, content: {
                VStack(spacing: 8) {
                    HStack {
                        Text("task_editor_unable_edit_recurrence".loc)
                            .foregroundColor(.secondary)
                    }
                    Button { [weak self] in
                        self?.presentEventEditor()
                    } label: {
                        Text("task_editor_edit_event".loc)
                            .font(.subheadline)
                    }
                }
            }))
            .tag("detached")
            .backgroundConfiguration(.clear())
        }
        .tag("detached event")
    }
    
    @MenuBuilder
    private var repeatingMenu: [MBMenu] {
        for rule in TaskRecurrenceRule.allCases {
            MBButton(rule.title, checked: event?.taskRecurrenceRule == rule) { [weak self] in
                guard let self, let event = self.event else { return }
                
                guard let recurrenceEndDate = event.recurrenceEndDate ?? event.normalizedEndDate?.nextWeek else {
                    assertionFailure("should has recurrence date")
                    return
                }
                
                event.setTaskRecurrenceRule(rule, end: .init(end: recurrenceEndDate))
                self.reload()
            }
        }
        
        MBGroup { [unowned self] in
            MBButton(TaskRecurrenceRule.custom(.init()).title, checked: event?.taskRecurrenceRule.isCustom == true) { [weak self] in
                guard let self else { return }
                
                self.presentEventEditor { vc in
                    vc.view.makeToast("task_editor_toast_on_custom_recurrence".loc, position: .center)
                }
                
                self.reload()
            }
        }
    }
    
    @ListBuilder
    private var editingHeader: [DLCell] {
        DLCell(using: .header(" "))
            .accessories([
                .labelButton(title: "task_editor_edit_event".loc, action: { [weak self] button in
                    self?.presentEventEditor()
                })
            ])
            .tag("calendarHeader")
    }
    
    @ListBuilder
    private func calendarSyncSettingsSection(event: EKEvent) -> [DLSection] {
        let errorMessage = taskRecurrenceEndDateError?.errorMessage
        
        DLSection { [unowned self] in
            editingHeader
            
            DLCell {
                DLText("repeating".loc)
            }
            .tag("repeat \(event.taskRecurrenceRule.title) \(forceReloadFlag)")
            .accessories(.popUpMenu(menu: .makeMenu(self.repeatingMenu),
                                    value: event.taskRecurrenceRule.title))
            
            if event.taskRecurrenceRule != .never, let endDate = event.recurrenceEndDate {
                DLCell(using: .datePicker(labelText: "repeating_end".loc,
                                          date: endDate,
                                          interval: recurrenceEndDatePickerInterval,
                                          valueDidChange: { [weak self] date in
                    guard let self, let event = self.event else { return }
                    
                    event.setTaskRecurrenceRule(event.taskRecurrenceRule,
                                                end: .init(end: date))
                    #if !targetEnvironment(macCatalyst)
                    self.reload(animating: false)
                    #endif
                }))
                .tag("repeat end \(self.event?.recurrenceEndDate?.description ?? "") \(self.recurrenceEndDatePickerInterval?.description ?? "")")
            }
        }
        .tag("repeating \(errorMessage ?? "")")
        .firstCellAsHeader()
        .listConfig { config in
            var config = config
            config.footerMode = .supplementary
            return config
        }
        .footer(using: .swiftUI(movingTo: { [unowned self] in self}, content: {
            if let errorMessage {
                PromptFooter(text: errorMessage,
                             isError: true)
            } else {
                Color.clear.frame(height: 16)
            }
        }))
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
    
    private var recurrenceEndDatePickerInterval: DateInterval? {
        guard let keyResultInfo, let start = task.normalizedEndDate else {
            return .twoYearsInterval
        }
        
        let endDate = keyResultInfo.goalDateInterval.end.endOfDay
        
        guard start <= endDate else {
            return nil
        }
        
        return .init(start: start, end: keyResultInfo.goalDateInterval.end.endOfDay)
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
