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
        Calendar.current.date(byAdding: .day, value: 7, to: self)!
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
    
    func days(to date: Date, includingLastDay: Bool = true) -> Int {
        let days = Calendar.current.dateComponents([.day], from: startOfDay, to: date.tomorrow.startOfDay).day ?? 0
        
        if !includingLastDay {
            return days - 1
        }
        
        return days
    }
    
    func formattedRelatively(includingTime: Bool = true) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = includingTime ? .short : .none
        formatter.dateStyle = .short
        formatter.doesRelativeDateFormatting = true
        
        return formatter.string(from: self)
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
