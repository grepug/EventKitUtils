//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/10/13.
//

import Foundation
import EventKit

public enum TaskDateValidationError: CaseIterable {
    case datesAbsence // 未设置时间
    case endDateEarlierThanStartDate // 结束时间早于开始时间
    case startDateEarlierThanGoalStartDate // 开始时间早于目标开始时间
    case dateIntervalIsNotContainedByTwoYearInterval // 未关联关键结果，任务时间范围不在两年时间范围内
    case endDateIsNotContainedByTwoYearInterval // 未关联关键结果，结束时间（非时间段）不在两年时间范围内
    case endDateLaterThanGoalEndDate // 结束时间晚于目标结束时间
}

public enum TaskRecurrenceEndDateValidationError: CaseIterable {
    case recurrenceEndDateEarlierThanStartDate // 结束重复日期早于开始时间
    case recurrenceEndDateLaterThanGoalEndDate // 结束重复日期晚于目标结束时间
    case recurrenceEndDateExceedsTwoYearInterval // 未关联关键结果，结束重复日期距离当前超过1年
}

public extension TaskKind {
    func validateDates(withKeyResultInfo krInfo: KeyResultInfo?) -> TaskDateValidationError? {
        guard let startDate = normalizedStartDate, let endDate = normalizedEndDate else {
            return .datesAbsence
        }
        
        let interval = DateInterval(start: startDate, end: endDate)
        
        for error in TaskDateValidationError.allCases {
            switch error {
            case .endDateEarlierThanStartDate:
                if endDate < startDate {
                    return error
                }
            case .startDateEarlierThanGoalStartDate:
                if let goalStartDate = krInfo?.goalDateInterval.start {
                    if startDate < goalStartDate {
                        return error
                    }
                }
            case .dateIntervalIsNotContainedByTwoYearInterval:
                if krInfo == nil {
                    if normalizedIsInterval && !DateInterval.twoYearsInterval.contains(interval) {
                        return error
                    }
                }
            case .endDateIsNotContainedByTwoYearInterval:
                if krInfo == nil {
                    if !normalizedIsInterval && !DateInterval.twoYearsInterval.contains(interval) {
                        return error
                    }
                }
            case .endDateLaterThanGoalEndDate:
                if let goalEndDate = krInfo?.goalDateInterval.end {
                    if endDate < goalEndDate {
                        return error
                    }
                }
            default:
                break
            }
        }
        
        return nil
    }
    
    func validateRecurrenceEndDate(withKeyResultInfo krInfo: KeyResultInfo?) -> TaskRecurrenceEndDateValidationError? {
        guard let event = self as? EKEvent else {
            return nil
        }
        
        guard let startDate = normalizedStartDate, let endDate = normalizedEndDate else {
            fatalError()
        }
        
        for error in TaskRecurrenceEndDateValidationError.allCases {
            switch error {
            case .recurrenceEndDateEarlierThanStartDate:
                if let recurrenceEndDate = event.recurrenceEndDate {
                    if recurrenceEndDate < startDate {
                        return error
                    }
                }
            case .recurrenceEndDateLaterThanGoalEndDate:
                if let recurrenceEndDate = event.recurrenceEndDate {
                    if let goalEndDate = krInfo?.goalDateInterval.end {
                        if recurrenceEndDate > goalEndDate {
                            return error
                        }
                    }
                }
            case .recurrenceEndDateExceedsTwoYearInterval:
                if krInfo == nil {
                    if let recurrenceEndDate = event.recurrenceEndDate {
                        if recurrenceEndDate > DateInterval.twoYearsInterval.end {
                            return error
                        }
                    }
                }
            }
        }
        
        return nil
    }
}
