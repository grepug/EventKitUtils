//
//  TaskKind.swift
//  
//
//  Created by Kai on 2022/7/20.
//

import Foundation
import SwiftUI
import EventKit

public enum TaskKindIdentifier {
    case event, managedObject
}

public protocol TaskKind {
    var normalizedID: String { get set }
    var normalizedTitle: String { get set }
    var normalizedStartDate: Date? { get set }
    var normalizedEndDate: Date? { get set }
    var originalIsAllDay: Bool { get set }
    var premisedIsDateEnabled: Bool? { get }
    var completedAt: Date? { get set }
    var abortedAt: Date? { get set }
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
        isAborted ? "❌" : isCompleted ? "✅" : "⭕️"
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
    
    var normalizedIsInterval: Bool {
        get {
            guard let startDate = normalizedStartDate, let endDate = normalizedEndDate else {
                return false
            }
            
            return isInterval(startAt: startDate, endAt: endDate, isAllDay: normalizedIsAllDay)
        }
        
        set {
            let (startDate, endDate) = calculateDefaultDates(isInterval: newValue, isAllDay: normalizedIsAllDay)
            normalizedStartDate = startDate
            normalizedEndDate = endDate
        }
    }
    
    var normalizedIsAllDay: Bool {
        get { originalIsAllDay }
        set {
            guard let _startDate = normalizedStartDate, let _endDate = normalizedEndDate else {
                return
            }
            
            let prevIsInterval = isInterval(startAt: _startDate, endAt: _endDate, isAllDay: normalizedIsAllDay)
            let (startDate, endDate) = calculateDefaultDates(isInterval: prevIsInterval, isAllDay: newValue)
            
            // The internal implementation force startDate and endDate to be the start of day, if isAllDay is on,
            // Therefore we need assign to ``isAllDay`` before assign to ``startDate`` and ``endDate``
            originalIsAllDay = newValue
            normalizedStartDate = startDate
            normalizedEndDate = endDate
        }
    }
    
    var dateInterval: DateInterval? {
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
        
        let interval = DateInterval(start: start, end: end)
        
        if normalizedIsAllDay {
            return interval.extendedToEdgesOfBothDates
        }
        
        return interval
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
        if state.isEnded {
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
    
    var isAborted: Bool {
        abortedAt != nil
    }
    
    func dateFormatted(endDateOnly: Bool = false) -> String? {
        guard let dateInterval else {
            return nil
        }
        
        return dateInterval.formattedRelatively(includingTime: !normalizedIsAllDay, endDateOnly: endDateOnly)
    }
    
    var value: TaskValue {
        let res = TaskValue(normalizedID: normalizedID,
                            normalizedTitle: normalizedTitle,
                            normalizedStartDate: normalizedStartDate,
                            normalizedEndDate: normalizedEndDate,
                            originalIsAllDay: normalizedIsAllDay,
                            premisedIsDateEnabled: premisedIsDateEnabled,
                            completedAt: completedAt,
                            abortedAt: abortedAt,
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
        originalIsAllDay = task.originalIsAllDay
        completedAt = task.completedAt
        abortedAt = task.abortedAt
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
    
    /// Assign the properties the task to the assignee
    ///
    /// For tasks that are not an EKEvent, make sure that
    ///  - their time components of ``normalizedStartDate`` and ``normalizedEndDate`` are the same.
    ///  - their task alarm types are the same if both assigner and assignee are EKEvents
    ///
    /// That's what repeating tasks should be.
    /// - Parameter task: the task kind assigner
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
        
        // assign the task alarm type if both assigner and assignee are EKEvents
        if let event1 = self as? EKEvent,
           let event2 = task as? EKEvent,
           let taskAlarmType = event2.taskAlarmType  {
            event1.setTaskAlarm(taskAlarmType)
        }
    }
    
    /// Postpone the task
    ///
    /// 
    mutating func postpone() {
        guard isDateEnabled,
              let durationInSeconds = dateInterval?.duration else {
            return
        }
        
        let duration = Int(durationInSeconds)
        let current = normalizedIsAllDay ? Date().startOfDay : Date()
        let endDate = Calendar.current.date(byAdding: .second, value: duration, to: current)?.endOfDay
        
        normalizedStartDate = current
        normalizedEndDate = endDate
    }
    
    mutating func toggleAbortion() {
        abortedAt = isAborted ? nil : Date()
        normalizedTitle = normalizedTitle
    }
}

private extension TaskKind {
    func isInterval(startAt startDate: Date, endAt endDate: Date, isAllDay: Bool) -> Bool {
        if isAllDay {
            return !startDate.isSameDay(with: endDate)
        }
        
        return startDate != endDate
    }
    
    func calculateDefaultDates(isInterval: Bool, isAllDay: Bool) -> (Date, Date) {
        let startDate: Date
        let endDate: Date
        
        if isAllDay {
            let date = Date()
            endDate = date
            
            if isInterval {
                startDate = date.yesterday
            } else {
                startDate = date
            }
        } else {
            let date = Date().nearestTime(in: .half)
            
            endDate = date
            
            if isInterval {
                startDate = date.prevHour
            } else {
                startDate = date
            }
        }
        
        return (startDate, endDate)
    }
}

public extension TaskKind {
    var state: TaskKindState {
        if isAborted {
            return .aborted
        }
        
        if isCompleted {
            return .completed
        }
        
        guard isDateEnabled,
              let endDate = normalizedEndDate,
              let range = dateInterval?.extendedToEdgesOfBothDates else {
            return .unscheduled
        }
        
        let current = Date()
        
        // if the date range contains current date, it is today
        if range.contains(current) {
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
            return [.today, .afterToday, .unscheduled].contains(state)
        case .completed:
            return isCompleted || state == .aborted
        }
    }
}

extension Date {
    /// Assign the time components (hour, minute, second, nanosecond) to the assignee
    /// - Parameter date: the date assigner
    /// - Returns: a new date with the same time components as the assignee
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

public extension String {
    var eventIDIgnoringRecurrenceID: String {
        String(split(separator: "/").first!)
    }
}

public extension Array where Element == TaskKind {
    /// Filter out duplicated IDs, ignoring recurrence suffix, e.g. /RID=xxxxxxxx
    var uniquedByIdIgnoringRecurrenceID: [Element] {
        uniqued { el in
            el.normalizedID.eventIDIgnoringRecurrenceID
        }
    }
    
    /// Filter out duplicated IDs
    var uniquedById: [Element] {
        uniqued(byID: \.normalizedID)
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
    
    func uniqued<T: Hashable>(byID id: (Element) -> T) -> [Element] {
        var res: [Element] = []
        var ids: Set<T> = []
        
        for el in self {
            let id = id(el)
            
            if ids.contains(id) {
                continue
            }
            
            res.append(el)
            ids.insert(id)
        }
        
        return res
    }
}
