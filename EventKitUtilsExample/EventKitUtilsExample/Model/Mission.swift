//
//  Mission.swift
//  EventKitUtilsExample
//
//  Created by Kai on 2022/7/20.
//

import Foundation
import EventKitUtils

class Mission: TaskKind {
    var id: String = UUID().uuidString
    var normalizedTitle: String = ""
    var normalizedStartDate: Date?
    var normalizedEndDate: Date?
    var isCompleted: Bool = false
    var completedAt: Date?
    var notes: String?
    var keyResultId: String?
    var linkedQuantity: Int?
    var createdAt: Date?
    var updatedAt: Date?
    
    var cellTag: String {
        ""
    }
    
    func toggleCompletion() {
        
    }
}
