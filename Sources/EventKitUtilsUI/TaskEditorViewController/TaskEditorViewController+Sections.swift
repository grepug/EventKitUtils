//
//  File.swift
//  
//
//  Created by Kai on 2022/8/5.
//

import DiffableList
import UIKit
import EventKitUtils

extension TaskEditorViewController {
    @ListBuilder
    var titleSection: [DLSection] {
        DLSection { [unowned self] in
            DLCell(using: .textField(text: self.task.normalizedTitle,
                                     placeholder: "v3_task_editor_title_ph".loc,
                                     editingDidEnd: { [unowned self] value in
                task.normalizedTitle = value
            }))
            .tag(task.normalizedTitle)
        }
        .tag("title \(self.task.normalizedTitle)")
    }
}

extension TaskEditorViewController {
    @ListBuilder
    var plannedDateSection: [DLSection] {
        DLSection { [unowned self] in
            DLCell {
                DLText("计划时间")
            }
            .tag("enable planDate \(isEvent) \(task.isDateEnabled)")
            .accessories([.toggle(isOn: task.isDateEnabled, isEnabled: !isEvent, action: { [unowned self] isOn in
                task.isDateEnabled = isOn
                reload()
            })])
            
            if task.isDateEnabled {
                DLCell {
                    DLText("全天")
                }
                .tag("is all day \(task.isDateEnabled.description) \(task.isAllDay.description)")
                .accessories([.toggle(isOn: task.isAllDay, action: { [unowned self] isOn in
                    task.isAllDay = isOn
                    reload()
                })])
                
                DLCell(using: .datePicker(labelText: "开始时间",
                                          date: task.normalizedStartDate ?? Date(),
                                          mode: datePickerMode,
                                          valueDidChange: { [unowned self] date in
                    task.normalizedStartDate = date
                }))
                .tag("startDate \(task.isDateEnabled) \(task.normalizedStartDate?.description ?? "") \(datePickerMode.rawValue)")
                
                DLCell(using: .datePicker(labelText: "结束时间",
                                          date: task.normalizedEndDate ?? Date(),
                                          mode: datePickerMode,
                                          valueDidChange: { [unowned self] date in
                    task.normalizedEndDate = date
                }))
                .tag("endDate \(task.isDateEnabled) \(task.normalizedEndDate?.description ?? "") \(datePickerMode)")
            }
        }
        .tag("2")
    }
}

extension TaskEditorViewController {
    @ListBuilder
    var keyResultLinkingSection: [DLSection] {
        DLSection { [unowned self] in
            if let krId = task.keyResultId,
               let krInfo = em.config.fetchKeyResultInfo?(krId) {
                DLCell {
                    DLImage(krInfo.emojiImage)
                    DLText(krInfo.title)
                    DLText(krInfo.goalTitle)
                        .secondary()
                        .color(.secondaryLabel)
                }
                .tag(krId)
                .accessories([.imageButton(image: .init(systemName: "xmark.circle.fill")!.colored(.secondaryLabel),
                                           action: { [unowned self] in
                    task.keyResultId = nil
                    reload()
                })])
            } else {
                DLCell {
                    DLText("关联关键结果")
                        .color(.accentColor)
                }
                .tag("link kr")
                .onTapAndDeselect { [unowned self] _ in
                    guard let vc = em.config.makeKeyResultSelector?({ [unowned self] krID in
                        task.keyResultId = krID
                        reload()
                    }) else {
                        return
                    }
                    
                    present(vc, animated: true)
                }
            }
            
        }
        .tag("3")
    }
}

extension TaskEditorViewController {
    @ListBuilder
    var calendarLinkingSection: [DLSection] {
        DLSection { [unowned self] in
            DLCell {
                DLText("同步到系统日历")
                DLText("设置提醒、重复任务")
                    .secondary()
                    .color(.secondaryLabel)
            }
            .tag("calendar \(isEvent)")
            .accessories([.label(isEvent ? "已开启" : "开启"), .disclosureIndicator()])
            .onTapAndDeselect { [unowned self] _ in
                presentEventEditor()
            }
        }
        .tag("4")
    }
    
    @ListBuilder
    var remarkSection: [DLSection] {
        DLSection { [unowned self] in
            DLCell(using: .textEditor(text: task.notes,
                                      placeholder: "v3_task_editor_remark".loc,
                                      action: { [unowned self] text in
                task.notes = text
            }))
            .tag("remarkEditor")
        }
        .tag("remark \(task.notes ?? "")")
    }
}

extension TaskEditorViewController {
    @ListBuilder
    var linkRecordSection: [DLSection] {
        DLSection { [unowned self] in
            DLCell(using: .header("v3_task_editor_linked_record".loc, using: .groupedHeader()))
                .tag("link record header")
            
            DLCell {
                DLText("开启关联记录值")
            }
            .tag("isLinkedRecord \(self.task.linkedValue != nil)")
            .accessories([.toggle(isOn: self.task.linkedValue != nil,
                                  action: { [unowned self] isOn in
                task.linkedValue = isOn ? 1 : nil
                em.saveTask(task)
                reload()
            })])
            
            if let linkedValueString = task.linkedValueString {
                DLCell(using: .textField(text: linkedValueString,
                                         placeholder: "v3_task_editor_linked_record_ph".loc,
                                         keyboardType: .decimalPad,
                                         editingDidEnd: { [unowned self] in
                    task.linkedValueString = $0
                    reload()
                }))
                .tag("linkedValue \(linkedValueString)")
                .disableHighlight()
            }
        }
        .tag("link record")
        .firstCellAsHeader()
        .footer("v3_task_editor_linked_record_footer".loc)
    }
}
