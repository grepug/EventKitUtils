//
//  File.swift
//  
//
//  Created by Kai on 2022/8/5.
//

import DiffableList
import UIKit
import EventKitUtils
import SwiftUI

extension TaskEditorViewController {
    @ListBuilder
    var titleSection: [DLSection] {
        DLSection { [unowned self] in
            DLCell(using: .textField(text: self.task.normalizedTitle,
                                     placeholder: "v3_task_editor_title_ph".loc,
                                     editingDidEnd: { [unowned self] value in
                task.normalizedTitle = value
                reload(animating: false)
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
                .tag("is all day \(task.isDateEnabled) \(task.normalizedIsAllDay)")
                .accessories([.toggle(isOn: task.normalizedIsAllDay, action: { [unowned self] isOn in
                    task.normalizedIsAllDay = isOn
                    reload()
                })])
                
                DLCell(using: .datePicker(labelText: "开始时间",
                                          date: task.normalizedStartDate!,
                                          mode: datePickerMode,
                                          valueDidChange: { [unowned self] date in
                    task.normalizedStartDate = date
                    reload(animating: false)
                }))
                .tag("startDate \(task.isDateEnabled) \(task.normalizedStartDate!.description) \(datePickerMode)")
                
                DLCell(using: .datePicker(labelText: "结束时间",
                                          date: task.normalizedEndDate!,
                                          mode: datePickerMode,
                                          valueDidChange: { [unowned self] date in
                    task.normalizedEndDate = date
                    reload(animating: false)
                }))
                .tag("endDate \(task.isDateEnabled) \(task.normalizedEndDate!.description) \(datePickerMode)")
            }
        }
        .tag("2 \(self.task.durationString ?? "") \(self.task.isDateEnabled)")
        .listConfig { [unowned self] config in
            var config = config
            config.footerMode = self.task.isDateEnabled ? .supplementary : .none
            return config
        }
        .footer(using: .swiftUI(movingTo: { [unowned self] in self}, content: { [unowned self] in
            Group {
                if let string = self.task.durationString {
                    Text(string)
                } else if let errorMessage = self.task.dateErrorMessage {
                    Label {
                        Text(errorMessage)
                    } icon: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .foregroundColor(.secondary)
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing)
            .padding([.top, .bottom], 8)
        }))
    }
}

extension TaskEditorViewController {
    @ListBuilder
    var keyResultLinkingSection: [DLSection] {
        DLSection { [unowned self] in
            if let krId = task.keyResultId,
               let krInfo = keyResultInfo {
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
                .onTapAndDeselect { [unowned self] _ in
                    presentKeyResultSelector()
                }
            } else {
                DLCell {
                    DLText("关联关键结果")
                        .color(.accentColor)
                }
                .tag("link kr")
                .onTapAndDeselect { [unowned self] _ in
                    presentKeyResultSelector()
                }
            }
            
        }
        .tag("3")
    }
    
    func presentKeyResultSelector() {
        guard let vc = em.config.makeKeyResultSelector?({ [unowned self] krID in
            task.keyResultId = krID
            reload()
        }) else {
            return
        }
        
        vc.modalPresentationStyle = .popover
        vc.popoverPresentationController?.sourceView = listView.cellForItem(at: [2, 0])
        
        present(vc, animated: true)
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
            .accessories([
                .label(isEvent ? "已开启" : "开启",
                       color: !isEvent ? .systemBlue : .secondaryLabel),
                isEvent ? .disclosureIndicator() : nil
            ])
            .onTapAndDeselect { [unowned self] _ in
                Task {
                    await presentEventEditor()
                }
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
    
    @ListBuilder
    var deleteButton: [DLSection] {
        DLSection { [unowned self] in
            DLCell(using: .swiftUI(movingTo: self, content: {
                Text("删除任务")
                    .foregroundColor(.red)
                    .frame(height: 44)
            }))
            .tag("deletion")
            .onTapAndDeselect { [unowned self] _ in
                Task {
                    await em.handleDeleteTask(task: task.value, on: self)
                    dismissEditor()
                }
            }
        }
        .tag("deletion")
    }
}

extension TaskEditorViewController {
    @ListBuilder
    var linkRecordSection: [DLSection] {
        DLSection { [unowned self] in
            DLCell {
                DLText("开启关联记录值")
                DLText("v3_task_editor_linked_record_footer".loc)
                    .secondary()
                    .color(.secondaryLabel)
            }
            .tag("isLinkedRecord \(self.task.linkedValue != nil)")
            .accessories([.toggle(isOn: self.task.linkedValue != nil,
                                  action: { [unowned self] isOn in
                Task {
                    task.linkedValue = isOn ? 1 : nil
                    await em.saveTask(task)
                    reload()
                }
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
    }
}
