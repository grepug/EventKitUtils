//
//  CahcedTask.swift
//  EventKitUtilsExample
//
//  Created by Kai Shao on 2022/9/10.
//

import StorageProvider
import EventKitUtils
import Foundation

extension CachedTask: SimpleManagedObject {
    
}

extension CachedTask: TaskKind, CachedTaskKind {
    public var state: EventKitUtils.TaskKindState {
        get {
            .init(rawValue: Int(state_))!
        }
        set(newValue) {
            state_ = Int16(newValue.rawValue)
        }
    }
    
    public var repeatingCount: Int? {
        get {
            Int(repeatCount)
        }
        set(newValue) {
            if let newValue {
                repeatCount = Int32(newValue)
            }
        }
    }
    
    public var order: Int {
        get {
            Int(order_)
        }
        
        set {
            order_ = Int32(newValue)
        }
    }
    
    public var normalizedRunID: String {
        get {
            runID ?? ""
        }
        set {
            runID = newValue
        }
    }
    
    public var normalizedID: String {
        get {
            idString ?? ""
        }
        set {
            idString = newValue
        }
    }
    
    public var normalizedTitle: String {
        get {
            title ?? ""
        }
        set(newValue) {
            title = newValue
        }
    }
    
    public var normalizedStartDate: Date? {
        get {
            startDate
        }
        set(newValue) {
            startDate = newValue
        }
    }
    
    public var normalizedEndDate: Date? {
        get {
            endDate
        }
        set(newValue) {
            endDate = newValue
        }
    }
    
    public var normalizedIsAllDay: Bool {
        get {
            isAllDay
        }
        set(newValue) {
            isAllDay = newValue
        }
    }
    
    public var premisedIsDateEnabled: Bool? {
        nil
    }
    
    public var completedAt: Date? {
        get {
            completionDate
        }
        set(newValue) {
            completionDate = newValue
        }
    }
    
    public var keyResultId: String? {
        get {
            keyResultID
        }
        set(newValue) {
            keyResultID = newValue
        }
    }
    
    public var linkedValue: Double? {
        get {
            hasLinkedRecordValue ? linkedRecordValue : nil
        }
        
        set(newValue) {
            if let newValue {
                linkedRecordValue = newValue
                hasLinkedRecordValue = true
            } else {
                hasLinkedRecordValue = false
            }
        }
    }
    
    public var kindIdentifier: EventKitUtils.TaskKindIdentifier? {
        .event
    }
    
    public var isValueType: Bool {
        false
    }
    
    public func toggleCompletion() {
        
    }
    
    public func updateVersion() {
        
    }
    
    
    func assignedFromTaskValue(_ taskValue: TaskValue) {
        idString = taskValue.normalizedID
        title = taskValue.normalizedTitle
        startDate = taskValue.normalizedStartDate
        endDate = taskValue.normalizedEndDate
        isAllDay = taskValue.normalizedIsAllDay
        completionDate = taskValue.completedAt
        notes = taskValue.notes
        keyResultID = taskValue.keyResultId
        linkedRecordValue = taskValue.linkedValue ?? 0
        isFirst = taskValue.isFirstRecurrence
    }
}
