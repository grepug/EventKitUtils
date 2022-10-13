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
                                     editingDidEnd: { [weak self] value in
                self?.task.normalizedTitle = value
                self?.reload(animating: false)
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
                DLText("时间段".loc)
            }
            .tag("is interval \(task.isDateEnabled) \(task.normalizedIsInterval)")
            .accessories([.toggle(isOn: task.normalizedIsInterval, action: { [unowned self] isOn in
                task.normalizedIsInterval = isOn
                reload()
            })])
            
            DLCell {
                DLText("task_editor_all_day".loc)
            }
            .tag("is all day \(task.isDateEnabled) \(task.normalizedIsAllDay)")
            .accessories([.toggle(isOn: task.normalizedIsAllDay, action: { [unowned self] isOn in
                task.normalizedIsAllDay = isOn
                reload()
            })])
            
            if task.normalizedIsInterval {
                DLCell(using: .datePicker(labelText: "task_editor_start_date".loc,
                                          date: task.normalizedStartDate!,
                                          mode: datePickerMode,
                                          valueDidChange: { [unowned self] date in
                    task.normalizedStartDate = date
                    #if !targetEnvironment(macCatalyst)
                    reload(animating: false)
                    #endif
                }))
                .tag("startDate \(task.isDateEnabled) \(task.normalizedStartDate!.description) \(datePickerMode)")
            }
            
            DLCell(using: .datePicker(labelText: task.normalizedIsInterval ? "task_editor_end_date".loc : "时间",
                                      date: task.normalizedEndDate!,
                                      mode: datePickerMode,
                                      valueDidChange: { [unowned self] date in
                if !task.normalizedIsInterval {
                    task.normalizedStartDate = date
                }
                
                task.normalizedEndDate = date
                
                #if !targetEnvironment(macCatalyst)
                reload(animating: false)
                #endif
            }))
            .tag("endDate \(task.isDateEnabled) \(task.normalizedEndDate!.description) \(datePickerMode) \(task.normalizedIsInterval)")
        }
        .tag("2 \(self.task.dateInterval?.formattedDurationString ?? "") \(self.task.isDateEnabled)")
        .listConfig { [unowned self] config in
            var config = config
            config.footerMode = showingDateSectionPromptFooter ? .supplementary : .none
            return config
        }
        .footer(using: .swiftUI(movingTo: { [unowned self] in self }, content: { [unowned self] in
            if let errorMessage = taskDateError?.errorMessage {
                PromptFooter(text: errorMessage, isError: true)
            } else if let text = task.dateInterval?.formattedDurationString {
                PromptFooter(text: text)
            }
        }))
    }
    
    var showingDateSectionPromptFooter: Bool {
        task.normalizedIsInterval || !hasNoError
    }
}

extension TaskEditorViewController {
    @ListBuilder
    var keyResultLinkingSection: [DLSection] {
        DLSection { [unowned self] in
            if let krInfo = keyResultInfo {
                DLCell {
                    DLImage(krInfo.emojiImage)
                    DLText(krInfo.title)
                    DLText(attributedString: krInfo.secondaryText)
                        .secondary()
                        .color(.secondaryLabel)
                }
                .tag(krInfo)
                .accessories([.imageButton(image: .init(systemName: "xmark.circle.fill")!.colored(.secondaryLabel),
                                           action: { [weak self] in
                    guard let self = self else { return }
                    
                    self.task.keyResultId = nil
                    self.keyResultInfo = nil
                    self.reload()
                })])
                .onTapAndDeselect { [weak self] _ in
                    self?.presentKeyResultSelector()
                }
            } else {
                DLCell {
                    DLText("task_editor_link_kr".loc)
                        .color(.accentColor)
                }
                .tag("link kr")
                .onTapAndDeselect { [weak self] _ in
                    self?.presentKeyResultSelector()
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
                                      action: { [weak self] isOn in
                    guard let self = self else { return }
                    
                    Task {
                        self.task.linkedValue = isOn ? 1 : nil
                        self.reload()
                    }
                })])
                
                if let linkedValueString = task.linkedValueString {
                    DLCell(using: .textField(text: linkedValueString,
                                             placeholder: "v3_task_editor_linked_record_ph".loc,
                                             keyboardType: .decimalPad,
                                             editingDidEnd: { [weak self] in
                        self?.task.linkedValueString = $0
                        self?.reload()
                    }))
                    .tag("linkedValue \(linkedValueString)")
                    .disableHighlight()
                }
            }
        }
        .tag("3")
    }
    
    func presentKeyResultSelector() {
        guard let vc = em.uiConfiguration?.makeKeyResultSelectorViewController(completion: { [weak self] krID in
            guard let self = self else { return }
            
            Task {
                self.task.keyResultId = krID
                await self.fetchKeyResultInfo()
                self.reload()
            }
        }) else {
            return
        }
        
        vc.modalPresentationStyle = .popover
        
        let indexPath: IndexPath = [1, 0]
        vc.popoverPresentationController?.sourceView = listView.cellForItem(at: indexPath)
        
        if let keyResultInfo {
            assert(listView.diffableDataSource.itemIdentifier(for: indexPath) == "\(keyResultInfo.hashValue)")
        } else {
            assert(listView.diffableDataSource.itemIdentifier(for: indexPath) == "link kr")
        }
        
        present(vc, animated: true)
    }
}

extension TaskEditorViewController {
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

extension KeyResultInfo {
    var secondaryText: NSAttributedString {
        let attributedString = NSMutableAttributedString(string: goalTitle + "\n")
        attributedString.append(.init(string: goalDateInterval.formattedDate()))
        
        return attributedString
    }
}
