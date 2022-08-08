//
//  File.swift
//  
//
//  Created by Kai on 2022/7/19.
//

import Foundation

public extension Date {
    func formatted(in type: DateFormatter.Style, timeStyle: DateFormatter.Style = .none) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = type
        formatter.timeStyle = timeStyle
        return formatter.string(from: self)
    }
    
    var tomorrow: Self {
        Calendar.current.date(byAdding: .day, value: 1, to: self)!
    }
    
    var startOfDay: Self {
        Calendar.current.startOfDay(for: self)
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
    
    func formattedRelatively() -> String {
        let days = Date().days(to: self, includingLastDay: false)
        
        switch days {
        case 0: return "task_date_today".loc
        case 1: return "task_date_tomorrow".loc
        default: return formatted(in: .medium)
        }
    }
}

extension String {
    var loc: Self {
        String(format: NSLocalizedString(self, bundle: .module, comment: ""), "")
    }
    
    func loc(_ string: String) -> Self {
        String(format: NSLocalizedString(self, bundle: .module, comment: ""), string)
    }
}

extension Double {
    func toString(toFixed fixed: Int, dropingDotZero: Bool = false) -> String {
        let string = String(format: "%.\(fixed)f", self)
        let decimal = truncatingRemainder(dividingBy: 1)
        
        if dropingDotZero && decimal == 0 {
            return String(Int(self))
        }
        
        return string
    }
}
