//
//  TaskValue.swift
//  
//
//  Created by Kai on 2022/8/3.
//

import Foundation
import Collections

public struct TaskValue: TaskKind, Equatable {
    public init(normalizedID: String = UUID().uuidString, normalizedTitle: String, normalizedStartDate: Date? = nil, normalizedEndDate: Date? = nil, normalizedIsAllDay: Bool = false, premisedIsDateEnabled: Bool? = nil, isCompleted: Bool = false, completedAt: Date? = nil, notes: String? = nil, keyResultId: String? = nil, linkedValue: Double? = nil, createdAt: Date? = nil, updatedAt: Date? = nil, isValueType: Bool = true, kindIdentifier: TaskKindIdentifier = .event, repeatingCount: Int? = nil, keyResultInfo: KeyResultInfo? = nil) {
        self.normalizedID = normalizedID
        self.normalizedTitle = normalizedTitle
        self.normalizedStartDate = normalizedStartDate
        self.normalizedEndDate = normalizedEndDate
        self.normalizedIsAllDay = normalizedIsAllDay
        self.premisedIsDateEnabled = premisedIsDateEnabled
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
    public var premisedIsDateEnabled: Bool?
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
    
    public func updateVersion() {
        fatalError("cannot update a value's version")
    }
    
    public var kindIdentifier: TaskKindIdentifier = .event
    public var repeatingCount: Int?
    public var keyResultInfo: KeyResultInfo?
    
    public var cellTag: String {
        normalizedID +
        normalizedTitle +
        (normalizedStartDate?.description ?? "startDate") +
        (normalizedEndDate?.description ?? "endDate") +
        isCompleted.description +
        (notes ?? "notes") +
        (keyResultId ?? "") +
        (linkedValueString ?? "") +
        ("\(repeatingCount ?? -1)")
    }
    
    func isSameTaskValueForRepeatTasks(with lhs: TaskValue) -> Bool {
        let rhs = self
        
        return lhs.normalizedID == rhs.normalizedID &&
        lhs.normalizedStartDate == rhs.normalizedStartDate &&
        lhs.normalizedEndDate == rhs.normalizedEndDate
    }
}

public extension Array where Element == TaskValue {
    func incompletedTasksAfter(_ date: Date, notEqualTo originalTaskValue: TaskValue) -> [TaskValue] {
        filter { task in
//            guard originalTaskValue.normalizedID != task.normalizedID else {
//                return false
//            }
            
            guard !task.isCompleted else {
                return false
            }
            
            if let endDate = task.normalizedEndDate {
                return endDate > date
            }
            
            return true
        }
    }
    
    typealias TitleGrouped = OrderedDictionary<TaskRepeatingInfo, [TaskValue]>
    typealias RepeatingGroupedCounts = [TaskRepeatingInfo: Int]
    
    func titleGrouped(iterator: ((Element) -> Void)? = nil) -> TitleGrouped {
        var cache: TitleGrouped = .init()
        
        for task in self {
            iterator?(task)
            
            guard !task.isCompleted else {
                continue
            }
            
            if cache[task.repeatingInfo] == nil {
                cache[task.repeatingInfo] = []
            }
            
            cache[task.repeatingInfo]!.append(task)
        }
        
        return cache
    }
    
    var countsOfRepeatingGrouped: RepeatingGroupedCounts {
        let titleGrouped = titleGrouped()
        var result: RepeatingGroupedCounts = [:]
        
        for (info, tasks) in titleGrouped {
            result[info] = tasks.count
        }
        
        return result
    }
    
    func repeatingMerged(withCountsOfTitleGrouped countsOfTitleGrouped: RepeatingGroupedCounts? = nil) -> [TaskValue] {
        var taskValues: [TaskValue] = []
        var completedTaskValues: [TaskValue] = []
        let cache = titleGrouped { task in
            if task.isCompleted {
                completedTaskValues.append(task)
            }
        }
        
        for (_, tasks) in cache {
            if var first = tasks.first {
                let info = first.repeatingInfo
                
                first.repeatingCount = countsOfTitleGrouped?[info] ??
                cache[info]?.count ??
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
                if let date1 = a.normalizedEndDate, let date2 = b.normalizedEndDate, date1 != date2 {
                    return date1 < date2
                }
            case .creationDateAsc:
                if let date1 = a.createdAt, let date2 = b.createdAt, date1 != date2 {
                    return date1 < date2
                }
            case .completionDesc:
                if let d1 = a.completedAt, let d2 = b.completedAt, d1 != d2 {
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
    
    public func sorted(in state: TaskKindState? = .today, of segment: FetchTasksSegmentType = .today) -> [TaskValue] {
        let sortTypes = SortType.sortTypes(in: state, of: segment)
        
        return sorted { a, b in
            for type in sortTypes {
                if let res = type.sorted(a, b) {
                    return res
                }
            }
            
            if a.normalizedTitle != b.normalizedTitle {
                return a.normalizedTitle < b.normalizedTitle
            }
            
            return a.normalizedID < b.normalizedID
        }
    }
}

