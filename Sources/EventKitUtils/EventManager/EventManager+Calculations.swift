//
//  File.swift
//  
//
//  Created by Kai on 2022/8/1.
//

import Foundation
import Combine

extension EventManager {
    typealias TasksByKeyResultID = [String: [TaskValue]]
    typealias RecordsByKeyResultID = [String: [RecordValue]]
    
    var valuesByKeyResultID: Future<(TasksByKeyResultID, RecordsByKeyResultID), Never> {
        Future { promise in
            DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
                var dict: TasksByKeyResultID = [:]
                var dict2: RecordsByKeyResultID = [:]
                let predicate = eventsPredicate()
                
                enumerateEvents(matching: predicate) { event in
                    if let keyResultId = event.keyResultId {
                        if dict[keyResultId] == nil {
                            dict[keyResultId] = []
                        }
                        
                        if dict2[keyResultId] == nil {
                            dict2[keyResultId] = []
                        }
                        
                        dict[keyResultId]!.append(event.value)
                        
                        if let value = event.linkedValue, let completedAt = event.completedAt {
                            let recordValue = RecordValue(id: UUID().uuidString,
                                                          value: value,
                                                          date: completedAt,
                                                          createdAt: Date(),
                                                          updatedAt: Date())
                            dict2[keyResultId]!.append(recordValue)
                        }
                    }
                    
                    return false
                }
                
                let res = (dict, dict2)
                
                promise(.success(res))
            }
        }
    }
    
    var allTasksPublisher: Future<[TaskValue], Never> {
        Future { [unowned self] promise in
            fetchTasksAsync(with: .segment(.today)) { tasks in
                promise(.success(tasks))
            }
        }
    }
}
