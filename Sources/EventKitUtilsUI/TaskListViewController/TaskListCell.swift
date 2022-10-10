//
//  TaskListCell.swift
//  Vision_3 (iOS)
//
//  Created by Kai on 2022/4/8.
//

import SwiftUI
import EventKitUtils

/// The content view for task list cell, implementing with SwiftUI
public struct TaskListCell: View {
    /// The initializer for ``TaskListCell``
    /// - Parameters:
    ///   - task: the task value
    ///   - currentStateRepeatingCount: the count for current state of repeating task
    ///   - isSummaryCard: a boolean indicates whether is for the Summary View Card
    ///   - checked: a boolean indicates whether the task is checked, which may be used as a temporary value
    ///   - showingNotes: a boolean indicates whether show the notes of the task
    ///   - hidingKRInfo: a boolean indicates whether hide the info of the key result
    ///   - hidingDate: a boolean indicates whether hide the dates
    ///   - hidingRepeatingCount: a boolean indicates whether hide the repeating count
    ///   - check: a method to toggle completion the task
    ///   - onTap: a method triggers when the whole task cell is tapped
    public init(task: TaskValue, currentStateRepeatingCount: Int? = nil, isSummaryCard: Bool = false, checked: Bool? = nil, showingNotes: Bool = false, hidingKRInfo: Bool = false, hidingDate: Bool = false, hidingRepeatingCount: Bool = false, check: @escaping () async -> Void, onTap: (() -> Void)? = nil) {
        self.task = task
        self.currentStateRepeatingCount = currentStateRepeatingCount
        self.isSummaryCard = isSummaryCard
        self.checked = checked
        self.showingNotes = showingNotes
        self.hidingKRInfo = hidingKRInfo
        self.hidingDate = hidingDate
        self.hidingRepeatingCount = hidingRepeatingCount
        self.check = check
        self.onTap = onTap
    }
    
    var task: TaskValue
    var currentStateRepeatingCount: Int?
    var isSummaryCard: Bool = false
    var checked: Bool?
    var showingNotes: Bool = false
    var hidingKRInfo: Bool = false
    var hidingDate: Bool = false
    var hidingRepeatingCount: Bool = false
    var check: () async -> Void
    var onTap: (() -> Void)?
    
    var repeatingCountString: String? {
        guard task.isRepeating else {
            return nil
        }
        
        let count = task.repeatingCount
        
        if let currentStateRepeatingCount {
            return "\(currentStateRepeatingCount) /\(count)"
        }
        
        return "\(count)"
    }
    
    public var body: some View {
        HStack(alignment: .top) {
            Group {
                switch task.state {
                case .aborted:
                    Image(systemName: "xmark.circle.fill")
                default:
                    Button {
                        Task {
                            await check()
                        }
                    } label: {
                        Image(systemName: (task.isCompleted || checked == true) ? "checkmark.circle.fill" : "circle")
                    }
                }
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
            onTap?()
        }
    }
    
    var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack {
                    Text(task.normalizedTitle)
                        .bold()
                        .foregroundColor(task.state.isEnded ? .gray : Color(UIColor.label))
                        
                    if task.kindIdentifier == .event {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Spacer()
            }
            
            if task.isDateEnabled || task.isRepeating {
                HStack {
                    if !hidingDate && task.isDateEnabled, let dateString = task.dateFormatted() {
                        Text(dateString)
                            .foregroundColor(task.dateColor)
                    }
                    
                    if !hidingRepeatingCount, let repeatingCount = repeatingCountString {
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
