//
//  TaskKind.swift
//  
//
//  Created by Kai on 2022/7/20.
//

import Foundation

public protocol TaskKind: AnyObject {
    var normalizedID: String { get }
    var normalizedTitle: String { get set }
    var normalizedStartDate: Date? { get set }
    var normalizedEndDate: Date? { get set }
    var isAllDay: Bool { get set }
    var isCompleted: Bool { get set }
    var completedAt: Date? { get set }
    var notes: String? { get set }
    var keyResultId: String? { get set }
    var linkedValue: Double? { get set }
    var createdAt: Date? { get }
    var updatedAt: Date? { get }
    
    func toggleCompletion()
}

public extension TaskKind {
    var isDateEnabled: Bool {
        get {
            normalizedStartDate != nil && normalizedEndDate != nil
        }
        
        set {
            if newValue {
                let date = Date()
                normalizedStartDate = date
                normalizedEndDate = Calendar.current.date(byAdding: .day, value: 1, to: date)
            } else {
                normalizedStartDate = nil
                normalizedEndDate = nil
            }
        }
    }
    
    var dateRange: Range<Date>? {
        guard let start = normalizedStartDate,
              let end = normalizedEndDate else {
            return nil
        }
        
        return start..<end
    }
    
    var cellTag: String {
        normalizedID +
        normalizedTitle +
        (normalizedStartDate?.description ?? "startDate") +
        (normalizedEndDate?.description ?? "endDate") +
        isCompleted.description
    }
}
