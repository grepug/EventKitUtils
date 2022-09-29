//
//  TaskKind.swift
//  
//
//  Created by Kai on 2022/7/20.
//

import Foundation
import SwiftUI

public enum TaskKindIdentifier {
    case event, managedObject
}

public protocol TaskKind {
    var normalizedID: String { get set }
    var normalizedTitle: String { get set }
    var normalizedStartDate: Date? { get set }
    var normalizedEndDate: Date? { get set }
    var normalizedIsAllDay: Bool { get set }
    var normalizedIsInterval: Bool { get set }
    var premisedIsDateEnabled: Bool? { get }
    var completedAt: Date? { get set }
    var notes: String? { get set }
    var keyResultId: String? { get set }
    var linkedValue: Double? { get set }
    var repeatingCount: Int? { get set }
    var createdAt: Date? { get }
    var updatedAt: Date? { get }
    
    var kindIdentifier: TaskKindIdentifier? { get }
    var isValueType: Bool { get }
    
    func toggleCompletion()
    func updateVersion()
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
            /// 优先判断的，兼容老数据
            if let premised = premisedIsDateEnabled {
                return premised
            }
            
            return normalizedStartDate != nil && normalizedEndDate != nil
        }
        
        set {
            if newValue {
                let date = Date()
                
                if normalizedStartDate == nil ||
                    normalizedEndDate == nil ||
                    /// 兼容老数据
                    premisedIsDateEnabled == false {
                    normalizedStartDate = date
                    normalizedEndDate = date.oneHourLater
                }
            } else {
                normalizedStartDate = nil
                normalizedEndDate = nil
            }
        }
    }
    
    var dateRange: Range<Date>? {
        guard isDateEnabled else {
            return nil
        }
        
        guard let start = normalizedStartDate,
              let end = normalizedEndDate else {
            return nil
        }
        
        guard start <= end else {
            return nil
        }
        
        if normalizedIsAllDay {
            return start.startOfDay..<end.endOfDay
        }
        
        return start..<end
    }
    
    var durationInSeconds: TimeInterval? {
        guard let dateRange = dateRange else {
            return nil
        }

        return dateRange.upperBound.timeIntervalSince1970 - dateRange.lowerBound.timeIntervalSince1970
    }
    
    var durationInDays: Int? {
        guard let dateRange = dateRange else {
            return nil
        }
        
        return abs(dateRange.upperBound.days(to: dateRange.lowerBound))
    }
    
    var durationString: String? {
        guard let interval = durationInSeconds else {
            return nil
        }
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .short

        return formatter.string(from: interval)!
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
    
    var dateColor: Color {
        if isCompleted {
            return .secondary
        }
        
        switch state {
        case .overdued: return .red
        case .today: return .green
        default: return .blue
        }
    }
    
    var isCompleted: Bool {
        completedAt != nil
    }
    
    func dateFormatted(endDateOnly: Bool = false) -> String? {
        guard let range = dateRange else {
            return nil
        }
        
        let startString = range.lowerBound.formattedRelatively(includingTime: !normalizedIsAllDay)
        let endString = range.upperBound.formattedRelatively(includingTime: !normalizedIsAllDay)
        
        if endDateOnly || startString == endString {
            return endString
        }
        
        return "\(startString) - \(endString)"
    }
    
    var value: TaskValue {
        let res = TaskValue(normalizedID: normalizedID,
                            normalizedTitle: normalizedTitle,
                            normalizedStartDate: normalizedStartDate,
                            normalizedEndDate: normalizedEndDate,
                            normalizedIsAllDay: normalizedIsAllDay,
                            premisedIsDateEnabled: premisedIsDateEnabled,
                            completedAt: completedAt,
                            notes: notes,
                            keyResultId: keyResultId,
                            linkedValue: linkedValue,
                            createdAt: createdAt,
                            updatedAt: updatedAt,
                            kindIdentifier: kindIdentifier,
                            repeatingCount: repeatingCount)
        
        return res
    }
    
    var repeatingInfo: TaskRepeatingInfo {
        .init(title: normalizedTitle, keyResultID: keyResultId)
    }
    
    mutating func assignFromTaskKind(_ task: TaskKind) {
        normalizedID = task.normalizedID
        normalizedTitle = task.normalizedTitle
        normalizedStartDate = task.normalizedStartDate
        normalizedEndDate = task.normalizedEndDate
        normalizedIsAllDay = task.normalizedIsAllDay
        completedAt = task.completedAt
        notes = task.notes
        keyResultId = task.keyResultId
        linkedValue = task.linkedValue
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
    
    mutating func assignAsRepeatingTask(from task: TaskKind) {
        normalizedTitle = task.normalizedTitle
        normalizedIsAllDay = task.normalizedIsAllDay
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
    
    mutating func postpone() {
        guard isDateEnabled,
              dateRange != nil,
              let durationInSeconds = durationInSeconds else {
            return
        }
        
        let duration = Int(durationInSeconds)
        let current = normalizedIsAllDay ? Date().startOfDay : Date()
        let endDate = Calendar.current.date(byAdding: .second, value: duration, to: current)?.endOfDay
        
        normalizedStartDate = current
        normalizedEndDate = endDate
    }
}

public extension TaskKind {
    var state: TaskKindState {
        guard isDateEnabled,
              let endDate = normalizedEndDate,
              let range = dateRange else {
            return .unscheduled
        }
        
        let current = Date()
        
        /// 包含今天，则为今天
        if range.contains(current) {
            return .today
        }
        
        if range.lowerBound.startOfDay == current.startOfDay {
            return .today
        }
        
        if endDate < current, !isCompleted {
            return .overdued
        }
        
        return .afterToday
    }
    
    func displayInSegment(_ segment: FetchTasksSegmentType) -> Bool {
        switch segment {
        case .today:
            if isCompleted {
                return [.today].contains(state)
            }
            
            return [.today, .overdued].contains(state)
        case .incompleted:
            return !isCompleted
        case .completed:
            return isCompleted
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

public extension Array where Element == TaskKind {
    /// 用来过滤掉日历创建的重复日程
    var uniquedById: [Element] {
        uniqued(by: \.normalizedID)
    }
}

public extension Array {
    func uniqued<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var res: [Element] = []
        var ids: Set<T> = []
        
        for el in self {
            let id = el[keyPath: keyPath]
            
            if ids.contains(id) {
                continue
            }
            
            res.append(el)
            ids.insert(id)
        }
        
        return res
    }
}
