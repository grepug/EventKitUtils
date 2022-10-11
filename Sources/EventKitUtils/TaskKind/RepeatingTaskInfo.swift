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
    public init(title: String, keyResultID: String?, state: TaskKindState? = nil) {
        self.title = title
        self.keyResultID = keyResultID
        self.state = state
    }
    
    public var title: String
    public var keyResultID: String?
    public var state: TaskKindState?
    
    public func predicate() -> NSPredicate {
        NSPredicate(format: "title == %@ && keyResultID == %@",
                    title as CVarArg,
                    keyResultID.map { $0 as CVarArg } ?? NSNull())
    }
    
    var stateRemoved: Self {
        var me = self
        me.state = nil
        return me
    }
}
