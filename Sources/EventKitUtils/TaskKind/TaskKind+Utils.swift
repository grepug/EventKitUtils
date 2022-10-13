//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/10/13.
//

import Foundation

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
