//
//  TaskKind.swift
//  
//
//  Created by Kai on 2022/7/20.
//

import Foundation

public protocol TaskKind: AnyObject {
    var id: String { get }
    var normalizedTitle: String { get set }
    var normalizedStartDate: Date? { get set }
    var normalizedEndDate: Date? { get set }
    var isAllDay: Bool { get set }
    var isCompleted: Bool { get set }
    var completedAt: Date? { get set }
    var notes: String? { get set }
    var keyResultId: String? { get set }
    var linkedQuantity: Int? { get set }
    var createdAt: Date? { get }
    var updatedAt: Date? { get }
    /// for DiffableListViewController
    var cellTag: String { get }
    
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
}
