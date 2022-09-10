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
    
//    var valuesByKeyResultID: AnyPublisher<ValuesResult?, Never> {
//        guard EKEventStore.authorizationStatus(for: .event) == .authorized else {
//            return Just(nil).eraseToAnyPublisher()
//        }
//
//        return Future { promise in
//            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
//                guard let self = self else { return }
//
//                var deferedAction: (() -> Void)?
//
//                if #available(iOS 15.0, *) {
//                    let key: StaticString = "valuesByKeyResultID"
//                    let signpostID = Self.signposter.makeSignpostID()
//                    let state = Self.signposter.beginInterval(key, id: signpostID)
//
//                    deferedAction = {
//                        Self.signposter.endInterval(key, state)
//                    }
//                }
//
//                defer {
//                    deferedAction?()
//                }
//
//                let res = self.calculate()
//
//                promise(.success(res))
//            }
//        }
//        .eraseToAnyPublisher()
//    }
    
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

extension EventManager {
    var makeCachePublisher: Future<Void, Never> {
        Future { promise in
            self.queue.async {
                Task {
                    await self.makeCache()
                    promise(.success(()))
                }
            }
        }
    }
    
    private func makeCache() async {
        Task {
            await cacheHandlers.clean()
        }
        
        let date = Date()
        let runID = await cacheHandlers.createRun(at: date)
            
        await withCheckedContinuation { continuation in
            self.queue.async {
                self.currentRunID = runID
                
                let (_tasks, state) = self.makeCacheImpl(runID: runID)
                
                Task {
                    await _tasks.awaitAll()
                    await self.cacheHandlers.setRunState(state, withID: runID)
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    private func makeCacheImpl(runID: String) -> ([Task<Void, Never>], CacheHandlersRunState) {
        var runState = CacheHandlersRunState.inProgress
        var _tasks: [Task<Void, Never>] = []
        var uniquedIDs: Set<String> = []
        
        var debugCount = 0
        
        enumerateEventsAndReturnsIfExceedsNonProLimit { [weak self] event in
            guard let self = self else {
                return true
            }
            
            debugCount += 1
            
            /// 当 `runID` 变化后，停止该遍历
            print("runID", self.currentRunID, runID)
            guard self.currentRunID == runID else {
                runState = .stopped
                return true
            }

            let isFirst = !uniquedIDs.contains(event.normalizedID)
            uniquedIDs.insert(event.normalizedID)
            
            let _task = Task {
                await self.cacheHandlers.createTask(event.value,
                                                    isFirst: isFirst,
                                                    withRunID: runID)
            }
            
            _tasks.append(_task)
            
            return false
        }
        
        if runState != .stopped {
            runState = .completed
        }
        
        print("debugCount", debugCount)
        
        return (_tasks, runState)
    }
}

/// 参考：
/// https://forums.swift.org/t/taskgroup-vs-an-array-of-tasks/53931/2
extension Array where Element == Task<Void, Never> {
    func awaitAll() async {
        await withTaskGroup(of: Void.self) { group in
            for task in self {
                group.addTask {
                    await task.value
                }
            }
        }
    }
}
