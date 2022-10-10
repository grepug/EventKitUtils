//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/9/16.
//

import Foundation
import StorageProvider

public protocol CachedTaskKind: SimpleManagedObject, TaskKind {
    var normalizedRunID: String { get set }
    var state: TaskKindState { get set }
    var order: Int { get set }
    var repeatingCount: Int { get set }
}
