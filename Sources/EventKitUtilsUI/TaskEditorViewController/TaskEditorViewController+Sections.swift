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
            .tag("title \(task.normalizedTitle)")
        }
        .tag("title \(self.task.normalizedTitle)")
    }
}

extension TaskEditorViewController {
    public override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        view.endEditing(true)
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }
    
    @ListBuilder
    var plannedDateSection: [DLSection] {
        DLSection { [unowned self] in
            DLCell {
                DLText("task_editor_plan_date".loc)
            }
            .tag("enable planDate \(isEvent) \(task.isDateEnabled)")
            .accessories([.toggle(isOn: task.isDateEnabled, isEnabled: !isEvent, action: { [unowned self] isOn in
                task.isDateEnabled = isOn
                task.updateVersion()
                reload()
            })])
            
            if task.isDateEnabled {
                DLCell {
                    DLText("task_editor_all_day".loc)
                }
                .tag("is all day \(task.isDateEnabled) \(task.normalizedIsAllDay)")
                .accessories([.toggle(isOn: task.normalizedIsAllDay, action: { [unowned self] isOn in
                    task.normalizedIsAllDay = isOn
                    task.updateVersion()
                    reload()
                })])
                
                DLCell(using: .datePicker(labelText: "task_editor_start_date".loc,
                                          date: task.normalizedStartDate!,
                                          mode: datePickerMode,
                                          valueDidChange: { [unowned self] date in
                    task.normalizedStartDate = date
                    task.updateVersion()
                    #if !targetEnvironment(macCatalyst)
                    reload(animating: false)
                    #endif
                }))
                .tag("startDate \(task.isDateEnabled) \(task.normalizedStartDate!.description) \(datePickerMode)")
                
                DLCell(using: .datePicker(labelText: "task_editor_end_date".loc,
                                          date: task.normalizedEndDate!,
                                          mode: datePickerMode,
                                          valueDidChange: { [unowned self] date in
                    task.normalizedEndDate = date
                    task.updateVersion()
                    #if !targetEnvironment(macCatalyst)
                    reload(animating: false)
                    #endif
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
                    DLText("task_editor_link_kr".loc)
                        .color(.accentColor)
                }
                .tag("link kr")
                .onTapAndDeselect { [unowned self] _ in
                    presentKeyResultSelector()
                }
            }
                
            if task.keyResultId != nil {
                DLCell {
                    DLText("task_editor_enable_link_record_value".loc)
                    DLText("v3_task_editor_linked_record_footer".loc)
                        .secondary()
                        .color(.secondaryLabel)
                }
                .tag("isLinkedRecord \(self.task.linkedValue != nil)")
                .accessories([.toggle(isOn: self.task.linkedValue != nil,
                                      action: { [unowned self] isOn in
                    Task {
                        task.linkedValue = isOn ? 1 : nil
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
                DLText("task_editor_sync_to_calendar".loc)
                DLText("task_editor_sync_to_calendar_desc".loc)
                    .secondary()
                    .color(.secondaryLabel)
            }
            .tag("calendar \(isEvent) \(forceReloadToggleFlag)")
            .disableHighlight(!isEvent)
            .accessories([
                .toggle(isOn: isEvent, isEnabled: !isEvent) { [unowned self] isOn in
                    guard isOn else {
                        fatalError("cannot turn off")
                    }
                    
                    Task {
                        await convertToEvent()
                        forceReloadToggleFlag += 1
                        reload()
                    }
                },
                isEvent ? .disclosureIndicator() : nil
            ])
            .onTapAndDeselect { [unowned self] _ in
                guard isEvent else {
                    return
                }
                
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
    
    @ListBuilder
    var deleteButton: [DLSection] {
        DLSection { [unowned self] in
            DLCell(using: .swiftUI(movingTo: self, content: {
                Text("task_editor_delete_button".loc)
                    .foregroundColor(.red)
                    .frame(height: 44)
            }))
            .tag("deletion")
            .onTapAndDeselect { [weak self] _ in
                guard let self = self else { return }
                
                Task {
                    await self.em.handleDeleteTask(task: self.task.value, on: self)
                    self.dismissEditor()
                }
            }
        }
        .tag("deletion")
    }
}
