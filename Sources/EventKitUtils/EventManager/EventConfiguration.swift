//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/9/19.
//

import UIKit

/// The required information for an instance of ``EventManager``
public protocol EventConfiguration {
    /// The base URL for EventKitUtils to save in the `url` field of an ``EKEvent``, identifying the ``EKEvent`` that is managed by EventKitUtils
    ///
    /// For example, the ``eventBaseURL`` is https://okr.vision/a , so that all events managed by EventKitUtils have the url field starting with https://okr.vision/a . It also appends parameters to this url to save information it needs.
    var eventBaseURL: URL { get }
    
    /// The app group identifier for the main app.
    ///
    /// Use for accessing ``UserDefaults`` in this app group container.
    var appGroupIdentifier: String? { get }
    
    /// The max count of events should return for non Pro users.
    ///
    /// It'll have no limits if returns nil
    var maxNonProLimit: Int? { get }
    
    /// Get the date interval which the EventKit should find calendar events in.
    ///
    /// Generally, it should return the earliest start date and the latest end date among all the goals the user created
    /// - Returns: a optional date interval (returns nil when there is no goal at all)
    func eventRequestDateInterval() async -> DateInterval?
    
    /// Get the task count for local tasks with the ``TaskRepeatingInfo``.
    /// - Parameter repeatingInfo: see in ``TaskRepeatingInfo``
    /// - Returns: an optional integer of the count
    func fetchNonEventTaskCount(with repeatingInfo: TaskRepeatingInfo) async -> Int?
    
    /// Fetch non event tasks by ``FetchTasksType``.
    /// - Parameter type: see ``FetchTasksType``
    /// - Returns: an array of ``TaskValue``
    func fetchNonEventTasks(type: FetchTasksType) async -> [TaskValue]
    
    /// Fetch a single non event task by its ID.
    /// - Parameters:
    ///   - id: the id string of the task
    ///   - creating: a boolean indicates whether is creating a new task
    /// - Returns: an optional ``TaskValue``
    func fetchNonEventTask(byID id: String, creating: Bool) async -> TaskValue?
    
    /// Save a non event task with the ``TaskValue``.
    /// - Parameter taskValue: the representation of the task, see ``TaskValue``
    func saveNonEventTask(_ taskValue: TaskValue) async
    
    /// Create a non event task
    /// - Returns: the ``TaskValue``
    func createNonEventTask() async -> TaskValue
    
    /// Delete a non event task by its ID.
    /// - Parameter id: the id string of the task
    func deleteNonEventTask(byID id: String) async
    
    /// Fetch key result information by its ID string.
    /// - Parameter id: id of the key result
    /// - Returns: ``KeyResultInfo``
    func fetchKeyResultInfo(byID id: String) async -> KeyResultInfo?
}

public extension EventConfiguration {
    var isPro: Bool {
        maxNonProLimit == nil
    }
}

/// The required information in terms of UIs for an instance of ``EventManager``.
public protocol EventUIConfiguration {
    /// Present an alert to inform the user that the feature requires Pro version.
    func presentNonProErrorAlert(on vc: UIViewController)
    
    /// The view controller which should be presented to select a linked key result.
    /// - Parameter completion: the completion handler to return the id of selected key result
    /// - Returns: the view controller
    func makeKeyResultSelectorViewController(completion: @escaping (String) -> Void) -> UIViewController
    
    /// The key result detail view controller
    /// - Parameter id: the id of the key result
    /// - Returns: an optional of the view controller
    func makeKeyResultDetailViewController(byID id: String) -> UIViewController?
    
    /// Log a message string
    ///
    /// which could be with Crashlylics, or system log
    /// - Parameter message: the message to log
    func log(_ message: String)
    
    
    /// Log an Error
    /// - Parameter error: the error to log
    func logError(_ error: Error)
}
