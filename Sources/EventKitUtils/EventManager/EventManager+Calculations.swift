//
//  File.swift
//  
//
//  Created by Kai on 2022/8/1.
//

import Foundation
import Combine
import EventKit

extension EventManager {
    typealias TasksByKeyResultID = [String: [TaskValue]]
    typealias RecordsByKeyResultID = [String: [RecordValue]]
    
    var valuesByKeyResultID: AnyPublisher<(TasksByKeyResultID, RecordsByKeyResultID)?, Never> {
        guard EKEventStore.authorizationStatus(for: .event) == .authorized else {
            return Just(nil).eraseToAnyPublisher()
        }
        
        return Future { promise in
            DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
                var dict: TasksByKeyResultID = [:]
                var dict2: RecordsByKeyResultID = [:]
                let predicate = eventsPredicate()
                
                enumerateEvents(matching: predicate) { event in
                    guard let keyResultId = event.keyResultId else {
                        return false
                    }
                    
                    if dict[keyResultId] == nil {
                        dict[keyResultId] = []
                    }
                    
                    dict[keyResultId]!.append(event.value)
                    
                    if let value = event.linkedValue, let completedAt = event.completedAt {
                        if dict2[keyResultId] == nil {
                            dict2[keyResultId] = []
                        }
                        
                        let recordValue = RecordValue(normalizedID: UUID().uuidString,
                                                      value: value,
                                                      date: completedAt,
                                                      notes: event.notes,
                                                      createdAt: Date(),
                                                      updatedAt: Date(),
                                                      linkedTaskID: event.normalizedID,
                                                      kindIdentifier: .event)
                        dict2[keyResultId]!.append(recordValue)
                    }
                    
                    return false
                }
                
                let res = (dict, dict2)
                
                promise(.success(res))
            }
        }
        .eraseToAnyPublisher()
    }
}
