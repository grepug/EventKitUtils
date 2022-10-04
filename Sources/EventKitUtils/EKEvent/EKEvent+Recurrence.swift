//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/9/22.
//

import EventKit

public enum TaskRecurrenceRule: CaseIterable {
    case never, daily, everyBusinessDay, weekly, everyTwoWeek, monthly, yearly, custom
    
    public init(ekRecurrenceRule rule: EKRecurrenceRule) {
        guard rule.daysOfTheWeek == nil &&
                rule.daysOfTheYear == nil &&
                rule.daysOfTheMonth == nil &&
                rule.monthsOfTheYear == nil &&
                rule.weeksOfTheYear == nil else {
            self = .custom
            return
        }
        
        switch rule.frequency {
        case .daily:
            self = .daily
        case .yearly:
            self = .yearly
        case .monthly:
            self = .monthly
        case .weekly:
            switch rule.interval {
            case 1:
                self = .weekly
            case 2:
                self = .everyTwoWeek
            default:
                self = .custom
            }
        @unknown default:
            self = .custom
        }
    }
    
    func ekRecurrenceRule(end: EKRecurrenceEnd? = nil) -> EKRecurrenceRule? {
        var interval = 1
        let frequency: EKRecurrenceFrequency
        
        switch self {
        case .never, .custom:
            return nil
        case .daily:
            frequency = .daily
        case .everyBusinessDay:
            return .init(recurrenceWith: .daily,
                         interval: 1,
                         daysOfTheWeek: [
                            .init(.monday),
                            .init(.tuesday),
                            .init(.wednesday),
                            .init(.thursday),
                            .init(.friday)
                         ],
                         daysOfTheMonth: nil,
                         monthsOfTheYear: nil,
                         weeksOfTheYear: nil,
                         daysOfTheYear: nil,
                         setPositions: nil,
                         end: end)
        case .weekly:
            frequency = .weekly
        case .everyTwoWeek:
            frequency = .weekly
            interval = 2
        case .monthly:
            frequency = .monthly
        case .yearly:
            frequency = .yearly
        }
        
        return .init(recurrenceWith: frequency, interval: interval, end: end)
    }
}

public extension EKEvent {
    var firstRecurrenceRule: EKRecurrenceRule? {
        guard hasRecurrenceRules, let rule = recurrenceRules?.first else {
            return nil
        }
        
        return rule
    }
    
    var recurrenceEndDate: Date? {
        guard let firstRecurrenceRule else {
            return nil
        }
        
        return firstRecurrenceRule.recurrenceEnd?.endDate
    }
    
    var taskRecurrenceRule: TaskRecurrenceRule {
        guard let firstRecurrenceRule else {
            return .never
        }
        
        return .init(ekRecurrenceRule: firstRecurrenceRule)
    }
    
    func removeAllRecurrenceRules() {
        guard hasRecurrenceRules, let recurrenceRules else {
            return
        }
        
        for recurrenceRule in recurrenceRules {
            removeRecurrenceRule(recurrenceRule)
        }
    }
    
    func setTaskRecurrenceRule(_ rule: TaskRecurrenceRule, end: EKRecurrenceEnd? = nil) {
        removeAllRecurrenceRules()
        
        if let rule = rule.ekRecurrenceRule(end: end) {
            addRecurrenceRule(rule)
        }
    }
}
