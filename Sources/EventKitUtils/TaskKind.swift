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
    var isCompleted: Bool { get set }
    var completedAt: Date? { get set }
    var notes: String? { get set }
    var keyResultId: String? { get set }
    var linkedQuantity: Int? { get set }
    var createdAt: Date? { get }
    var updatedAt: Date? { get }
    
    func toggleCompletion()
}
