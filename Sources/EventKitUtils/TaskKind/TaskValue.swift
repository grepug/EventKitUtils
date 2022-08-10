//
//  TaskValue.swift
//  
//
//  Created by Kai on 2022/8/3.
//

import Foundation
import Collections

public struct TaskValue: TaskKind, Hashable {
    public init(normalizedID: String = UUID().uuidString, normalizedTitle: String, normalizedStartDate: Date? = nil, normalizedEndDate: Date? = nil, normalizedIsAllDay: Bool = false, isCompleted: Bool = false, completedAt: Date? = nil, notes: String? = nil, keyResultId: String? = nil, linkedValue: Double? = nil, createdAt: Date? = nil, updatedAt: Date? = nil, isValueType: Bool = true, kindIdentifier: TaskKindIdentifier = .event, repeatingCount: Int? = nil, keyResultInfo: KeyResultInfo? = nil) {
        self.normalizedID = normalizedID
        self.normalizedTitle = normalizedTitle
        self.normalizedStartDate = normalizedStartDate
        self.normalizedEndDate = normalizedEndDate
        self.normalizedIsAllDay = normalizedIsAllDay
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.notes = notes
        self.keyResultId = keyResultId
        self.linkedValue = linkedValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isValueType = isValueType
        self.kindIdentifier = kindIdentifier
        self.repeatingCount = repeatingCount
        self.keyResultInfo = keyResultInfo
    }
    
    public var normalizedID: String = UUID().uuidString
    public var normalizedTitle: String
    public var normalizedStartDate: Date?
    public var normalizedEndDate: Date?
    public var normalizedIsAllDay: Bool = false
    public var isCompleted: Bool = false
    public var completedAt: Date?
    public var notes: String?
    public var keyResultId: String?
    public var linkedValue: Double?
    public var createdAt: Date?
    public var updatedAt: Date?
    public var isValueType: Bool = true
    
    public func toggleCompletion() {
        fatalError("cannot toggle a value' completion")
    }
    
    public var kindIdentifier: TaskKindIdentifier = .event
    public var repeatingCount: Int?
    public var keyResultInfo: KeyResultInfo?
}

public extension Array where Element == TaskValue {
    func incompletedTasksAfter(_ date: Date, notEqualTo originalTaskValue: TaskValue) -> [TaskValue] {
        filter { task in
            guard originalTaskValue.normalizedID != task.normalizedID else {
                return false
            }
            
            guard !task.isCompleted else {
                return false
            }
            
            guard let endDate = task.normalizedEndDate else {
                return false
            }
                
            return endDate > date
        }
    }
    
    typealias TitleGrouped = OrderedDictionary<String, [TaskValue]>
    
    func titleGrouped(iterator: ((Element) -> Void)? = nil) -> TitleGrouped {
        var cache: TitleGrouped = .init()
        
        for task in self {
            iterator?(task)
            
            guard !task.isCompleted else {
                continue
            }
            
            if cache[task.normalizedTitle] == nil {
                cache[task.normalizedTitle] = []
            }
            
            cache[task.normalizedTitle]!.append(task)
        }
        
        return cache
    }
    
    var countsOfTitleGrouped: [String: Int] {
        let titleGrouped = titleGrouped()
        var result: [String: Int] = [:]
        
        for (title, tasks) in titleGrouped {
            result[title] = tasks.count
        }
        
        return result
    }
    
    func repeatingMerged(withCountsOfTitleGrouped countsOfTitleGrouped: [String: Int]? = nil) -> [TaskValue] {
        var taskValues: [TaskValue] = []
        var completedTaskValues: [TaskValue] = []
        let cache = titleGrouped { task in
            if task.isCompleted {
                completedTaskValues.append(task)
            }
        }
        
        for (_, tasks) in cache {
            if var first = tasks.first {
                let title = first.normalizedTitle
                
                first.repeatingCount = countsOfTitleGrouped?[title] ??
                cache[title]?.count ??
                tasks.count
                
                taskValues.append(first)
            }
        }
        
        return taskValues + completedTaskValues
    }
}

extension Array where Element == TaskValue {
    enum SortType {
        case endDateAsc, creationDateAsc, completionDesc
        
        func sorted(_ a: TaskValue, _ b: TaskValue) -> Bool? {
            if a.isCompleted != b.isCompleted {
                return b.isCompleted
            }
            
            switch self {
            case .endDateAsc:
                if let date1 = a.normalizedEndDate, let date2 = b.normalizedEndDate {
                    return date1 < date2
                }
            case .creationDateAsc:
                if let date1 = a.createdAt, let date2 = b.createdAt {
                    return date1 < date2
                }
            case .completionDesc:
                if let d1 = a.completedAt, let d2 = b.completedAt {
                    return d1 > d2
                }
            }
            
            return nil
        }
        
        static func sortTypes(in state: TaskKindState?, of segment: FetchTasksSegmentType) -> [Self] {
            if let state = state {
                if [.today, .overdued, .afterToday].contains(state) {
                    return [.endDateAsc, .creationDateAsc]
                }
                
                if state == .unscheduled {
                    return [.creationDateAsc]
                }
                
                assert(false, "no way for this")
            }
            
            assert(segment == .completed, "only Completed segment has state of nil")
            
            return [.completionDesc]
        }
        
        static var keyResultDetailSortTypes: [Self] {
            [.endDateAsc, creationDateAsc]
        }
    }
    
    public func sorted(in state: TaskKindState?, of segment: FetchTasksSegmentType) -> [TaskValue] {
        let sortTypes = SortType.sortTypes(in: state, of: segment)
        
        return sorted { a, b in
            for type in sortTypes {
                if let res = type.sorted(a, b) {
                    return res
                }
            }
            
            return true
        }
    }
}
