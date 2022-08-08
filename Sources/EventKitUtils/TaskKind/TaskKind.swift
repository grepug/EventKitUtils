//
//  TaskKind.swift
//  
//
//  Created by Kai on 2022/7/20.
//

import Foundation

public enum TaskKindIdentifier {
    case event, managedObject
}

public protocol TaskKind {
    var normalizedID: String { get }
    var normalizedTitle: String { get set }
    var normalizedStartDate: Date? { get set }
    var normalizedEndDate: Date? { get set }
    var isAllDay: Bool { get set }
    var isCompleted: Bool { get set }
    var completedAt: Date? { get set }
    var notes: String? { get set }
    var keyResultId: String? { get set }
    var linkedValue: Double? { get set }
    var createdAt: Date? { get }
    var updatedAt: Date? { get }
    
    var kindIdentifier: TaskKindIdentifier { get }
    var isValueType: Bool { get }
    
    func toggleCompletion()
}

public extension TaskKind {
    var isEmpty: Bool {
        normalizedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var emoji: String {
        isCompleted ? "✅" : "⭕️"
    }
    
    var isDateEnabled: Bool {
        get {
            normalizedStartDate != nil && normalizedEndDate != nil
        }
        
        set {
            if newValue {
                let date = Date()
                
                if normalizedStartDate == nil || normalizedEndDate == nil {
                    normalizedStartDate = date
                    normalizedEndDate = date.oneHourLater
                }
            } else {
                normalizedStartDate = nil
                normalizedEndDate = nil
            }
        }
    }
    
    mutating func setStartDate(_ date: Date?) {
        if let startDate = date {
            normalizedStartDate = startDate
            
            if let endDate = normalizedEndDate, endDate <= startDate {
                normalizedEndDate = startDate.oneHourLater
            }
        } else {
            normalizedStartDate = nil
        }
    }
    
    mutating func setEndDate(_ date: Date?) {
        if let endDate = date {
            normalizedEndDate = endDate
            
            if let startDate = normalizedStartDate, endDate <= startDate {
                normalizedStartDate = endDate.oneHourEarlier
            }
        } else {
            normalizedEndDate = nil
        }
    }
    
    var dateRange: Range<Date>? {
        guard let start = normalizedStartDate,
              let end = normalizedEndDate else {
            return nil
        }
        
        guard start <= end else {
            return nil
        }
        
        if isAllDay {
            return start.startOfDay..<end.endOfDay
        }
        
        return start..<end
    }
    
    var linkedValueString: String? {
        get {
            guard let value = linkedValue else {
                return nil
            }
            
            return value.toString(toFixed: 2)
        }
        
        set {
            if let valueString = newValue {
                linkedValue = Double(valueString)
            } else {
                linkedValue = nil
            }
        }
    }
    
    var cellTag: String {
        normalizedID +
        normalizedTitle +
        (normalizedStartDate?.description ?? "startDate") +
        (normalizedEndDate?.description ?? "endDate") +
        isCompleted.description
    }
    
    var value: TaskValue {
        .init(normalizedID: normalizedID,
              normalizedTitle: normalizedTitle,
              normalizedStartDate: normalizedStartDate,
              normalizedEndDate: normalizedEndDate,
              isAllDay: isAllDay,
              isCompleted: isCompleted,
              completedAt: completedAt,
              notes: notes,
              keyResultId: keyResultId,
              linkedValue: linkedValue,
              createdAt: createdAt,
              updatedAt: updatedAt,
              kindIdentifier: kindIdentifier)
    }
    
    func testAreDatesSame(from task: TaskKind) -> Bool {
        guard let startDate = normalizedStartDate,
              let startDate2 = task.normalizedStartDate,
              let endDate = normalizedEndDate,
              let endDate2 = task.normalizedEndDate else {
            return false
        }
        
        return startDate.testIsDateSame(from: startDate2) && endDate.testIsDateSame(from: endDate2)
    }
    
    mutating func saveAsRepeatingTask(from task: TaskKind) {
        normalizedTitle = task.normalizedTitle
        isAllDay = task.isAllDay
        notes = task.notes
        keyResultId = task.keyResultId
        linkedValue = task.linkedValue
        
        if let startDate = normalizedStartDate, let startDate2 = task.normalizedStartDate {
            let date = startDate.timeAssigned(from: startDate2)
            normalizedStartDate = date
        }
        
        if let endDate = normalizedEndDate, let endDate2 = task.normalizedEndDate {
            let date = endDate.timeAssigned(from: endDate2)
            normalizedEndDate = date
        }
    }
}

extension Date {
    func timeAssigned(from date: Date) -> Date {
        let components = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        var selfComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: self)
        
        selfComponents.hour = components.hour
        selfComponents.minute = components.minute
        selfComponents.second = components.second
        selfComponents.nanosecond = components.nanosecond
        
        return Calendar.current.date(from: selfComponents)!
    }
    
    func testIsDateSame(from date: Date) -> Bool {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let selfComponents = Calendar.current.dateComponents([.year, .month, .day], from: self)
        
        return components == selfComponents
    }
}
