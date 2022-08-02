//
//  File.swift
//  
//
//  Created by Kai on 2022/8/1.
//

import Foundation

public protocol RecordKind {
    var id: String { get }
    var value: Double { get set }
    var date: Date { get set }
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var recordValue: RecordValue { get }
}

public struct RecordValue: RecordKind, Hashable {
    public init(id: String, value: Double, date: Date, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.value = value
        self.date = date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public var id: String
    public var value: Double
    public var date: Date
    public var createdAt: Date
    public var updatedAt: Date
    public var recordValue: RecordValue { self }
}
