//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/9/30.
//

import Foundation

public extension Date {
    func formatted(in type: DateFormatter.Style, timeStyle: DateFormatter.Style = .none) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = type
        formatter.timeStyle = timeStyle
        formatter.locale = Locale.current
        return formatter.string(from: self)
    }
    
    var tomorrow: Self {
        Calendar.current.date(byAdding: .day, value: 1, to: self)!
    }
    
    var yesterday: Self {
        Calendar.current.date(byAdding: .day, value: -1, to: self)!
    }
    
    var startOfDay: Self {
        Calendar.current.startOfDay(for: self)
    }
    
    var startOfHour: Self {
        let hour = Calendar.current.dateComponents([.hour], from: self).hour!
        
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: self)!
    }
    
    var nextHour: Self {
        Calendar.current.date(byAdding: .hour, value: 1, to: self)!
    }
    
    var prevHour: Self {
        Calendar.current.date(byAdding: .hour, value: -1, to: self)!
    }
    
    var nextWeek: Self {
        Calendar.current.date(byAdding: .day, value: 6, to: self)!
    }
    
    var endOfDay: Self {
        let date1 = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        return Calendar.current.date(byAdding: .second, value: -1, to: date1)!
    }
    
    var oneHourLater: Self {
        Calendar.current.date(byAdding: .hour, value: 1, to: self)!
    }
    
    var oneHourEarlier: Self {
        Calendar.current.date(byAdding: .hour, value: -1, to: self)!
    }
    
    func isSameDay(with date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: self) ||
        abs(date.timeIntervalSince1970 - timeIntervalSinceNow) < 3 * 60
    }
    
    func days(to date: Date, includingLastDay: Bool = true) -> Int {
        let days = abs(Calendar.current.dateComponents([.day], from: startOfDay, to: date.tomorrow.startOfDay).day ?? 0)
        
        if !includingLastDay {
            return days - 1
        }
        
        return days
    }
    
    var weekDayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        
        return formatter.string(from: self)
    }
    
    func dateAssigned(from date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: self)
        let year = components.year!
        let month = components.month!
        let day = components.day!
        var newDate = date
        
        newDate = Calendar.current.date(bySetting: .year, value: year, of: newDate)!
        newDate = Calendar.current.date(bySetting: .month, value: month, of: newDate)!
        newDate = Calendar.current.date(bySetting: .day, value: day, of: newDate)!
        newDate = Calendar.current.date(bySetting: .hour, value: date.component(.hour), of: newDate)!
        newDate = Calendar.current.date(bySetting: .minute, value: date.component(.minute), of: newDate)!
        newDate = Calendar.current.date(bySetting: .second, value: date.component(.second), of: newDate)!
        
        assert(newDate.component(.day) == component(.day))
        assert(newDate.component(.hour) == date.component(.hour))
        assert(newDate.component(.minute) == date.component(.minute))
        
        return newDate
    }
    
    func formattedRelatively(includingTime: Bool = true, includingDate: Bool = true) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = includingTime ? .short : .none
        formatter.dateStyle = includingDate ? .short : .none
        formatter.doesRelativeDateFormatting = true
        let dateString = formatter.string(from: self)
        
        if includingDate {
            return "\(weekDayString), \(dateString)"
        }
        
        return dateString
    }
    
    func component(_ component: Calendar.Component) -> Int {
        Calendar.current.component(component, from: self)
    }
}

public extension DateInterval {
    var extendedToEdgesOfBothDates: DateInterval {
        .init(start: start.startOfDay, end: end.endOfDay)
    }
    
    func durationInDays(includingLastDay: Bool = true) -> Int {
        start.days(to: end, includingLastDay: includingLastDay)
    }
    
    var formattedDurationString: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .full
        
        return formatter.string(from: duration + 1)!
    }
    
    func formattedRelatively(includingTime: Bool = true, endDateOnly: Bool = false) -> String {
        let startString = start.formattedRelatively(includingTime: includingTime)
        
        if start == end || endDateOnly {
            return startString
        }
        
        let isSameDate = start.isSameDay(with: end)
        let endString = end.formattedRelatively(includingTime: includingTime,
                                                includingDate: !isSameDate)
        
        if endString.isEmpty {
            return startString
        }
        
        return "\(startString) - \(endString)"
    }
    
    func formattedDate() -> String {
        "\(start.formatted(in: .medium, timeStyle: .none)) - \(end.formatted(in: .medium, timeStyle: .none))"
    }
    
    func largerInterval(with interval: DateInterval) -> DateInterval {
        var start: Date = start
        var end: Date = end
        
        if start > interval.start {
            start = interval.start
        }
        
        if end < interval.end {
            end = interval.end
        }
        
        return .init(start: start, end: end)
    }
    
    func contains(_ interval: DateInterval) -> Bool {
        contains(interval.start) && contains(interval.end)
    }
    
    static var twoYearsInterval: DateInterval {
        let current = Date()
        let start = Calendar.current.date(byAdding: .year, value: -1, to: current)!
        let end = Calendar.current.date(byAdding: .year, value: 1, to: current)!
        
        return .init(start: start, end: end)
    }
}

public extension Date {
    enum NeareastTimeType {
        case half, hour
    }
    
    func nearestTime(in type: NeareastTimeType = .half) -> Date {
        let min = Calendar.current.component(.minute, from: self)
        
        switch type {
        case .hour:
            if min > 30 {
                return nextHour.startOfHour
            }
            
            return startOfHour
        case .half:
            switch min {
            case 0..<15:
                return startOfHour
            case 15..<30:
                return Calendar.current.date(bySetting: .minute, value: 30, of: self)!
            default:
                return startOfHour.nextHour
            }
        }
    }
}
