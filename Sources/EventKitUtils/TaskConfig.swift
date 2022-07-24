//
//  File.swift
//  
//
//  Created by Kai on 2022/7/24.
//

import Foundation

public struct TaskConfig {
    public init(eventBaseURL: URL, createNonEventTask: @escaping () -> TaskKind) {
        self.eventBaseURL = eventBaseURL
        self.createNonEventTask = createNonEventTask
    }
    
    let eventBaseURL: URL
    var createNonEventTask: () -> TaskKind
}
