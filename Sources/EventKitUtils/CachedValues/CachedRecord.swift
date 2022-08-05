//
//  File.swift
//  
//
//  Created by Kai on 2022/8/1.
//

import Foundation

public enum RecordKindIdentifier {
    case event, managedObject
}

public protocol RecordKind {
    var normalizedID: String { get }
    var value: Double { get set }
    var date: Date? { get set }
    var createdAt: Date? { get set }
    var updatedAt: Date? { get set }
    var notes: String? { get set }
    var hasLinkedTask: Bool { get }
    var isValueType: Bool { get }
    var kindIdentifier: RecordKindIdentifier { get }
    
    var recordValue: RecordValue { get }
}

public extension RecordKind {
    var valueString: String {
        get { value.toString(toFixed: 2) }
        set { value = Double(newValue) ?? 0 }
    }
    
    var dateString: String {
        (date ?? Date()).formatted(in: .short)
    }
}

public struct RecordValue: RecordKind, Hashable {
    public init(normalizedID: String, value: Double, date: Date? = nil, notes: String? = nil, createdAt: Date? = nil, updatedAt: Date? = nil, hasLinkedTask: Bool, kindIdentifier: RecordKindIdentifier) {
        self.normalizedID = normalizedID
        self.value = value
        self.date = date
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.hasLinkedTask = hasLinkedTask
        self.kindIdentifier = kindIdentifier
    }

    public var normalizedID: String
    public var value: Double
    public var date: Date?
    public var notes: String?
    public var createdAt: Date?
    public var updatedAt: Date?
    public var recordValue: RecordValue { self }
    public var hasLinkedTask: Bool
    public var kindIdentifier: RecordKindIdentifier
    
    public var isValueType: Bool { true }
}

public extension Collection where Element: RecordKind {
    var recordValues: [RecordValue] {
        map(\.recordValue)
    }
}
