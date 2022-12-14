//
//  TaskListCell.swift
//  Vision_3 (iOS)
//
//  Created by Kai on 2022/4/8.
//

import SwiftUI
import EventKitUtils

public struct TaskListCell: View {
    public init(task: TaskValue, isSummaryCard: Bool = false, checked: Bool? = nil, showingNotes: Bool = false, hidingKRInfo: Bool = false, hidingDate: Bool = false, check: @escaping () async -> Void, presentEditor: (() -> Void)? = nil) {
        self.task = task
        self.isSummaryCard = isSummaryCard
        self.checked = checked
        self.showingNotes = showingNotes
        self.hidingKRInfo = hidingKRInfo
        self.hidingDate = hidingDate
        self.check = check
        self.presentEditor = presentEditor
    }
    
    var task: TaskValue
    var isSummaryCard: Bool = false
    var checked: Bool?
    var showingNotes: Bool
    var hidingKRInfo: Bool = false
    var hidingDate: Bool = false
    var check: () async -> Void
    var presentEditor: (() -> Void)?
    
    
    public var body: some View {
        HStack(alignment: .top) {
            Button {
                Task {
                   await check()
                }
            } label: {
                Image(systemName: (task.isCompleted || checked == true) ? "checkmark.circle.fill" : "circle")
            }
            .foregroundColor(.gray)
            .offset(y: 2.5)
            
            if isSummaryCard {
                content
                    .padding(.bottom, 12)
                    .border(width: 0.3, edges: [.bottom], color: Color(UIColor.separator))
            } else {
                content
            }
        }
        .padding(isSummaryCard ? [.horizontal] : .all)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            presentEditor?()
        }
    }
    
    var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack {
                    Text(task.normalizedTitle)
                        .bold()
                        .foregroundColor(task.isCompleted ? .gray : Color(UIColor.label))
                        
                    if task.kindIdentifier == .event {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Spacer()
                
//                if task.notes?.isEmpty == false {
//                    Image(systemName: "")
//                        .foregroundColor(.gray)
//                }
            }
            
            if task.isDateEnabled || (task.repeatingCount ?? 0) > 1 {
                HStack {
                    if !hidingDate && task.isDateEnabled, let dateString = task.dateFormatted() {
                        Text(dateString)
                            .foregroundColor(task.dateColor)
                    }
                    
                    if let repeatingCount = task.repeatingCount, repeatingCount > 1 {
                        Label("\(repeatingCount)", systemImage: "repeat")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
            }
            
            if !hidingKRInfo, let krInfo = task.keyResultInfo {
                HStack {
                    HStack(spacing: 4) {
                        Text(krInfo.title)
                            .lineLimit(1)

                        if let value = task.linkedValue {
                            Rectangle()
                                .frame(width: 0.3, height: 8)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 2)
                            Text("v3_task_list_reord_value".loc + "\(value)")
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
//                .padding(.bottom, task.notes.isEmpty != true ? 4 : 0)
            }
            
            if showingNotes, let notes = task.notes, !notes.isEmpty {
                Text(notes)
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .lineLimit(5)
            }
        }
    }
}
