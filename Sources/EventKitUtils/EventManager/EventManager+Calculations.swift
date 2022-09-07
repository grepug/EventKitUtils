//
//  File.swift
//  
//
//  Created by Kai on 2022/8/1.
//

import Foundation
import Combine
import EventKit
import os

extension EventManager {
    typealias TasksByKeyResultID = [String: [TaskValue]]
    typealias RecordsByKeyResultID = [String: [RecordValue]]
    typealias ValuesResult = (TasksByKeyResultID, RecordsByKeyResultID)
    
    @available(iOS 15.0, *)
    static let signposter = OSSignposter()
    
    var valuesByKeyResultID: AnyPublisher<ValuesResult?, Never> {
        guard EKEventStore.authorizationStatus(for: .event) == .authorized else {
            return Just(nil).eraseToAnyPublisher()
        }
        
        return Future { promise in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                var deferedAction: (() -> Void)?
                
                if #available(iOS 15.0, *) {
                    let key: StaticString = "valuesByKeyResultID"
                    let signpostID = Self.signposter.makeSignpostID()
                    let state = Self.signposter.beginInterval(key, id: signpostID)
                    
                    deferedAction = {
                        Self.signposter.endInterval(key, state)
                    }
                }
                
                defer {
                    deferedAction?()
                }
                
                let res = self.calculate()
                
                promise(.success(res))
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func calculate() -> ValuesResult? {
        var dict: TasksByKeyResultID = [:]
        var dict2: RecordsByKeyResultID = [:]
        
        enumerateEventsAndReturnsIfExceedsNonProLimit { event in
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
        
        return (dict, dict2)
    }
}
