//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/9/22.
//

import EventKit

public enum TaskRecurrenceRule: Equatable {
    case never,
         daily,
         everyWorkDay,
         everyWeekendDay,
         weekly,
         everyTwoWeek,
         monthly,
         yearly,
         custom(EKRecurrenceRule)
    
    public static var allCases: [TaskRecurrenceRule] {
        return [.never,
                .daily,
                .everyWorkDay,
                .everyWeekendDay,
                .weekly,
                .everyTwoWeek,
                .monthly,
                .yearly,]
    }
    
    public init(ekRecurrenceRule rule: EKRecurrenceRule) {
        guard rule.daysOfTheYear == nil &&
                rule.daysOfTheMonth == nil &&
                rule.monthsOfTheYear == nil &&
                rule.weeksOfTheYear == nil else {
            self = .custom(rule)
            return
        }
        
        if let daysOfTheWeek = rule.daysOfTheWeek {
            let days = Set(daysOfTheWeek.map(\.dayOfTheWeek))
            
            switch days {
            case EKWeekday.weekendDays:
                self = .everyWeekendDay
            case EKWeekday.workDays:
                self = .everyWorkDay
            default:
                self = .custom(rule)
            }
            
            return
        }
        
        let interval = rule.interval
        
        switch rule.frequency {
        case .daily where interval == 1:
            self = .daily
        case .yearly where interval == 1:
            self = .yearly
        case .monthly where interval == 1:
            self = .monthly
        case .weekly where interval == 1:
            self = .weekly
        case .weekly where interval == 2:
            self = .everyTwoWeek
        default:
            self = .custom(rule)
        }
    }
    
    func ekRecurrenceRule(end: EKRecurrenceEnd? = nil) -> EKRecurrenceRule? {
        var interval = 1
        let frequency: EKRecurrenceFrequency
        
        switch self {
        case .never:
            return nil
        case .custom(let ekRule):
            return ekRule
        case .daily:
            frequency = .daily
        case .weekly:
            frequency = .weekly
        case .everyTwoWeek:
            frequency = .weekly
            interval = 2
        case .monthly:
            frequency = .monthly
        case .yearly:
            frequency = .yearly
        case .everyWeekendDay:
            return .daysOfTheWeek(EKWeekday.weekendDays, end: end)
        case .everyWorkDay:
            return .daysOfTheWeek(EKWeekday.workDays, end: end)
        }
        
        return .init(recurrenceWith: frequency, interval: interval, end: end)
    }
    
    public var isCustom: Bool {
        switch self {
        case .custom: return true
        default: return false
        }
    }
}

extension EKRecurrenceRule {
    static func daysOfTheWeek(_ daysOfTheWeek: Set<EKWeekday>, end: EKRecurrenceEnd?) -> EKRecurrenceRule {
        .init(recurrenceWith: .daily,
              interval: 1,
              daysOfTheWeek: daysOfTheWeek.map { .init($0) },
              daysOfTheMonth: nil,
              monthsOfTheYear: nil,
              weeksOfTheYear: nil,
              daysOfTheYear: nil,
              setPositions: nil,
              end: end)
    }
}

extension EKWeekday {
    static var allCases: Set<EKWeekday> {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }
    
    static var weekendDays: Set<EKWeekday> {
        [.saturday, .sunday]
    }
    
    static var workDays: Set<EKWeekday> {
        allCases.subtracting(weekendDays)
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
    
    func setTaskRecurrenceRule(_ rule: TaskRecurrenceRule, end: EKRecurrenceEnd) {
        removeAllRecurrenceRules()

        switch rule {
        case .custom(let ekRule):
            let rule = ekRule.copied(end: end)
            addRecurrenceRule(rule)
        default:
            if let rule = rule.ekRecurrenceRule(end: end) {
                addRecurrenceRule(rule)
            }
        }
    }
}

public extension EKEvent {
    func setDefaultRecurrenceEndIfAbsents(savingWithEventStore eventStore: EKEventStore) {
        if let rule = firstRecurrenceRule, recurrenceEndDate == nil {
            removeAllRecurrenceRules()
            addRecurrenceRule(rule.copied(end: .init(end: endDate.nextWeek)))
            try! eventStore.save(self, span: .futureEvents, commit: true)
        }
    }
}

public extension EKRecurrenceRule {
    func copied(end: EKRecurrenceEnd) -> EKRecurrenceRule {
        .init(recurrenceWith: frequency, interval: interval, daysOfTheWeek: daysOfTheWeek, daysOfTheMonth: daysOfTheMonth, monthsOfTheYear: monthsOfTheYear, weeksOfTheYear: weeksOfTheYear, daysOfTheYear: daysOfTheYear, setPositions: setPositions, end: end)
    }
}
