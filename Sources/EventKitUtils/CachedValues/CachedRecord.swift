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
    var value: Double { get }
    var date: Date? { get set }
    var createdAt: Date? { get }
    var updatedAt: Date? { get }
    var notes: String? { get }
    var linkedTaskID: String? { get }
    var isValueType: Bool { get }
    var kindIdentifier: RecordKindIdentifier { get }
    var recordValue: RecordValue { get }
}

public extension RecordKind {
    var valueString: String {
        get { value.toString(toFixed: 2) }
    }
    
    var dateString: String {
        (date ?? Date()).formatted(in: .short)
    }
}

public struct RecordValue: RecordKind, Hashable {
    public init(normalizedID: String, value: Double, date: Date? = nil, notes: String? = nil, createdAt: Date? = nil, updatedAt: Date? = nil, linkedTaskID: String? = nil, kindIdentifier: RecordKindIdentifier, taskValue: TaskValue? = nil) {
        self.normalizedID = normalizedID
        self.value = value
        self.date = date
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.linkedTaskID = linkedTaskID
        self.kindIdentifier = kindIdentifier
        self.taskValue = taskValue
    }
    
    public init?(withTaskValue task: TaskValue) {
        guard let linkedValue = task.linkedValue,
              let completedAt = task.completedAt else {
            return nil
        }
        
        normalizedID = UUID().uuidString
        value = linkedValue
        date = completedAt
        notes = task.notes
        createdAt = Date()
        updatedAt = createdAt
        linkedTaskID = task.normalizedID
        kindIdentifier = .event
        taskValue = task
    }

    public var normalizedID: String
    public var value: Double
    public var date: Date?
    public var notes: String?
    public var createdAt: Date?
    public var updatedAt: Date?
    public var recordValue: RecordValue { self }
    public var linkedTaskID: String?
    public var kindIdentifier: RecordKindIdentifier
    public var taskValue: TaskValue?
    
    public var isValueType: Bool { true }
}

public extension Collection where Element: RecordKind {
    var recordValues: [RecordValue] {
        map(\.recordValue)
    }
}

public extension Array where Element == RecordValue {
    func sorted() -> [Element] {
        return filter { $0.date != nil }
            .sorted { a, b in
                guard let date1 = a.date, let date2 = b.date else {
                    fatalError()
                }
                
                return date1 > date2
            }
    }
}
