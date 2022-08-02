//
//  TaskListCell.swift
//  Vision_3 (iOS)
//
//  Created by Kai on 2022/4/8.
//

import SwiftUI

struct TaskListCell: View {
    var task: TaskKind
    var recurenceCount: Int?
    var linkedKeyResultTitle: String?
    var hidingGoal: Bool = false
    var hidingDate: Bool = false
    var check: () -> Void
    var presentEditor: () -> Void
    
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
    
    var body: some View {
        HStack(alignment: .top) {
            Button {
                check()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
            }
            .foregroundColor(task.isCompleted ? .gray : .accentColor)
            .offset(y: 2.5)
            
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
                            
                        if let recurenceCount = recurenceCount {
                            Label("\(recurenceCount)", systemImage: "repeat")
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
        .padding()
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            presentEditor()
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
