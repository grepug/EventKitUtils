//
//  TaskListCell.swift
//  Vision_3 (iOS)
//
//  Created by Kai on 2022/4/8.
//

import SwiftUI
import EventKitUtils

public struct TaskListCell: View {
    public init(task: TaskValue, isSummaryCard: Bool = false, linkedKeyResultTitle: String? = nil, hidingGoal: Bool = false, hidingDate: Bool = false, check: @escaping () -> Void, presentEditor: (() -> Void)? = nil) {
        self.task = task
        self.isSummaryCard = isSummaryCard
        self.linkedKeyResultTitle = linkedKeyResultTitle
        self.hidingGoal = hidingGoal
        self.hidingDate = hidingDate
        self.check = check
        self.presentEditor = presentEditor
    }
    
    var task: TaskValue
    var isSummaryCard: Bool = false
    var linkedKeyResultTitle: String?
    var hidingGoal: Bool = false
    var hidingDate: Bool = false
    var check: () -> Void
    var presentEditor: (() -> Void)?
    
    var relativeDateColor: Color {
//        let days = task.plannedDate.map { Date.current.days(to: $0, includingLastDay: false) } ?? 1
//
//        if days == 0 {
//            return .accentColor
//        }
//
//        if days < 0 {
//            return .red
//        }
        
        return .accentColor
    }
    
    public var body: some View {
        HStack(alignment: .top) {
            Button {
                check()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
            }
            .foregroundColor(task.isCompleted ? .gray : .accentColor)
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
                
                if task.notes?.isEmpty == false {
                    Image(systemName: "")
                        .foregroundColor(.gray)
                }
            }
            
            if !hidingDate && task.isDateEnabled, let dateString = dateString(task) {
                HStack {
                    Text(dateString)
                        .foregroundColor(relativeDateColor)
                        
                    if let repeatingCount = task.repeatingCount, repeatingCount > 1 {
                        Label("\(repeatingCount)", systemImage: "repeat")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
            }
            
            if !hidingGoal, let title = linkedKeyResultTitle {
                HStack {
                    HStack(spacing: 4) {
                        Text(title)

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
        }
    }
}

extension TaskListCell {
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        formatter.doesRelativeDateFormatting = true
        
        return formatter.string(from: date)
    }
    
    func dateString(_ task: TaskKind) -> String? {
        if let endDate = task.normalizedEndDate, task.normalizedStartDate == nil {
            return formatDate(endDate)
        }
        
        if let range = task.dateRange {
            return "\(formatDate(range.lowerBound)) - \(formatDate(range.upperBound))"
        }
        
        return nil
    }
}
