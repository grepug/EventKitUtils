//
//  Mission.swift
//  EventKitUtilsExample
//
//  Created by Kai on 2022/7/20.
//

import Foundation
import EventKitUtils
import StorageProvider

extension Mission: SimpleManagedObject, TaskKind {
    public var repeatingCount: Int? {
        get {
            nil
        }
        set(newValue) {
            
        }
    }
    
    public var normalizedIsAllDay: Bool {
        get {
            isAllDay
        }
        set {
            isAllDay = newValue
        }
    }
    
    public var premisedIsDateEnabled: Bool? {
        nil
    }
    
    public func updateVersion() {
        
    }
    
    public var linkedValue: Double? {
        get { linkedRecordValue }
        set { linkedRecordValue = newValue ?? 0 }
    }
    
    public var keyResultId: String? {
        get {
            linkedKeyResultId?.uuidString
        }
        set(newValue) {
            linkedKeyResultId = UUID(uuidString: newValue!)
        }
    }
    
    public var normalizedTitle: String {
        get { title ?? "" }
        set { title = newValue }
    }
    
    public var normalizedID: String {
        get { id?.uuidString ?? "" }
        set { id = UUID(uuidString: newValue) }
    }
    
    public var normalizedStartDate: Date? {
        get { startDate }
        set { startDate = newValue }
    }
    
    public var normalizedEndDate: Date? {
        get { endDate }
        set { endDate = newValue }
    }
    
    public func toggleCompletion() {
        isCompleted.toggle()
    }
    
    public var kindIdentifier: TaskKindIdentifier? {
        .managedObject
    }
    
    public var isValueType: Bool {
        false
    }
}
