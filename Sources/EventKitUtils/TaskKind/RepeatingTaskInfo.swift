//
//  File.swift
//  
//
//  Created by Kai on 2022/8/11.
//

import Foundation

/// The common information that a group of repeating tasks share.
///
/// which are the title of the task and key result's ID.
public struct TaskRepeatingInfo: Hashable {
    public init(title: String, keyResultID: String?) {
        self.title = title
        self.keyResultID = keyResultID
    }
    
    public var title: String
    public var keyResultID: String?
}
