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
}
