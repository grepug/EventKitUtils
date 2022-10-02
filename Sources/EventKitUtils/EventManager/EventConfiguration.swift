//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/9/19.
//

import UIKit

public protocol EventConfiguration {
    var eventBaseURL: URL { get }
    var appGroupIdentifier: String? { get }
    var maxNonProLimit: Int? { get }
    var eventRequestRange: Range<Date> { get }
    
    func fetchTaskCount(with repeatingInfo: TaskRepeatingInfo) async -> Int?
    func fetchNonEventTasks(type: FetchTasksType) async -> [TaskValue]
    func createNonEventTask() async -> TaskValue
    func fetchTask(byID id: String, creating: Bool) async -> TaskValue?
    func saveTask(_ taskValue: TaskValue) async
    func deleteTask(byID id: String) async
    func fetchKeyResultInfo(byID id: String) async -> KeyResultInfo?
}

public extension EventConfiguration {
    var isPro: Bool {
        maxNonProLimit == nil
    }
}

public protocol EventUIConfiguration {
    func presentNonProErrorAlert()
    func makeKeyResultSelector(completion: @escaping (String) -> Void) -> UIViewController
    func makeKeyResultDetail(byID id: String) -> UIViewController?
    
    func log(_ message: String)
    func logError(_ error: Error)
}
