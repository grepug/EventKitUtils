//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/9/9.
//

import Foundation
import Combine

public protocol CacheHandlers {
    func currentRunID() async -> String?
    func fetchTaskValues(by type: FetchTasksType, firstOnly: Bool) async -> [TaskValue]
    func fetchRecordValuesByKeyResultID(_ id: String) async -> [RecordValue]
    
    func createRun(id: String, at date: Date) async
    func setRunState(_ state: CacheHandlersRunState, withID id: String) async
    func createTask(_ taskValue: TaskValue, isFirst: Bool, withRunID runID: String) async
    
    func clean() async
}

public enum CacheHandlersRunState: Int {
    case inProgress, stopped, completed
}

extension CacheHandlers {
    func createRunPublisher(id: String, at date: Date) -> Future<Void, Never> {
        Future { promise in
            Task {
                await createRun(id: id, at: date)
                promise(.success(()))
            }
        }
    }
    
    func createTaskPublisher(_ taskValue: TaskValue, isFirst: Bool, withRunID runID: String) -> Future<Void, Never> {
        Future { promise in
            Task {
                await createTask(taskValue, isFirst: isFirst, withRunID: runID)
                promise(.success(()))
            }
        }
    }
    
    func setRunStatePublisher(_ state: CacheHandlersRunState, withID id: String) -> Future<Void, Never> {
        Future { promise in
            Task {
                await setRunState(state, withID: id)
                promise(.success(()))
            }
        }
    }
}
