//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/9/9.
//

import Foundation

public protocol CacheHandlers {
    func currentRunID() async -> String?
    func fetchTaskValues(by type: FetchTasksType, firstOnly: Bool) async -> [TaskValue]
    func fetchRecordValuesByKeyResultID(_ id: String) async -> [RecordValue]
    
    func createRun(at date: Date) async -> String
    func setRunState(_ state: CacheHandlersRunState, withID id: String) async
    func createTask(_ taskValue: TaskValue, isFirst: Bool, withRunID runID: String) async
    
    func clean() async
}

public enum CacheHandlersRunState: Int {
    case inProgress, stopped, completed
}
