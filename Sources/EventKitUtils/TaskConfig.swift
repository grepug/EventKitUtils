//
//  File.swift
//  
//
//  Created by Kai on 2022/7/24.
//

import Foundation

public struct TaskConfig {
    public init(eventBaseURL: URL, eventRequestRange: Range<Date>? = nil , createNonEventTask: @escaping () -> TaskKind, taskById: @escaping (String) -> TaskKind?) {
        self.eventBaseURL = eventBaseURL
        self.createNonEventTask = createNonEventTask
        self.taskById = taskById
        
        let start = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let end = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        self.eventRequestRange = start..<end
    }
    
    
    let eventBaseURL: URL
    var eventRequestRange: Range<Date>
    var createNonEventTask: () -> TaskKind
    var taskById: (String) -> TaskKind?
}
