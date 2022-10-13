//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/10/4.
//

import Foundation
import EventKit

public struct TaskAlarmType: Equatable {
    init(title: String, offset: TimeInterval) {
        self.title = title
        self.offset = offset
    }
    
    public var title: String
    public var offset: TimeInterval
    
    public init(ekAlarm: EKAlarm) {
        for type in Self.allCases {
            if type.offset == ekAlarm.relativeOffset {
                self = type
                return
            }
        }
        
        self = .timeOfEvent
    }
}

public extension TaskAlarmType {
    static let timeOfEvent: Self = .init(title: "alarm_type_timeOfEvent".loc, offset: 0)
    static let fiveMinBefore: Self = .init(title: "alarm_type_fiveMinBefore".loc, offset: -5 * 60)
    static let tenMinBefore: Self = .init(title: "alarm_type_tenMinBefore".loc, offset: -10 * 60)
    static let fifteenMinBefore: Self = .init(title: "alarm_type_fifteenMinBefore".loc, offset: -15 * 60)
    static let thirtyMinBefore: Self = .init(title: "alarm_type_thirtyMinBefore".loc, offset: -30 * 60)
    static let oneHourBefore: Self = .init(title: "alarm_type_oneHourBefore".loc, offset: -60 * 60)
    static let twoHoursBefore: Self = .init(title: "alarm_type_twoHoursBefore".loc, offset: -2 * 60 * 60)
    static let oneDayBefore: Self = .init(title: "alarm_type_oneDayBefore".loc, offset: -24 * 60 * 60)
    static let twoDaysBefore: Self = .init(title: "alarm_type_twoDaysBefore".loc, offset: -2 * 24 * 60 * 60)
    static let oneWeekBefore: Self = .init(title: "alarm_type_oneWeekBefore".loc, offset: -7 * 24 * 60 * 60)
    
    static var allCases: [TaskAlarmType] {
        [
            .timeOfEvent,
            .fiveMinBefore,
            .tenMinBefore,
            .fifteenMinBefore,
            .thirtyMinBefore,
            .oneHourBefore,
            .twoHoursBefore,
            .oneDayBefore,
            .twoDaysBefore,
            .oneWeekBefore
        ]
    }
}

public extension EKEvent {
    var firstAlarm: EKAlarm? {
        guard hasAlarms, let alarm = alarms?.first else {
            return nil
        }
        
        return alarm
    }
    
    var taskAlarmType: TaskAlarmType? {
        guard let alarm = firstAlarm else {
            return nil
        }
        
        return .init(ekAlarm: alarm)
    }
    
    func removeAllTaskAlarms() {
        guard hasAlarms, let alarms else {
            return
        }
        
        for alarm in alarms {
            removeAlarm(alarm)
        }
    }
    
    func setTaskAlarm(_ alarmType: TaskAlarmType) {
        removeAllTaskAlarms()
        addAlarm(.init(relativeOffset: alarmType.offset))
    }
}
