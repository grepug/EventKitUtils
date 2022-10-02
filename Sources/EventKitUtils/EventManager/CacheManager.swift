//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/9/11.
//

import Foundation
import Combine
import EventKit

public actor CacheManager {
    init(eventStore: EKEventStore, eventConfiguration: EventConfiguration, handlers: CacheHandlers) {
        self.eventStore = eventStore
        self.eventConfiguration = eventConfiguration
        self.handlers = handlers
    }
    
    var eventStore: EKEventStore
    var eventConfiguration: EventConfiguration
    var handlers: CacheHandlers
    var currentRunID: String?
    var uniquedIDs: Set<String> = []
    public var isPending: Bool = false
}

extension CacheManager {
    public func makeCache() async {
        guard !isPending else {
            return
        }
        
        isPending = true
        
        let runID = UUID().uuidString
        
        try? await handlers.clean(exceptRunID: runID)
        await makeCacheImpl(runID: runID)
        
        isPending = false
    }
    
    private var eventEnumerator: EventEnumerator {
        .init(eventStore: eventStore, eventConfiguration: eventConfiguration)
    }
    
    private func makeCacheImpl(runID: String) async {
        var tasks: CacheHandlersTaskValuesDict = [:]
        
        eventEnumerator.enumerateEventsAndReturnsIfExceedsNonProLimit { event, completion in
            let id = event.normalizedID.eventIDIgnoringRecurrenceID
            let state = event.state
            
            if tasks[id] == nil {
                tasks[id] = [:]
            }
            
            if tasks[id]![state] == nil {
                tasks[id]![state] = []
            }
            
            tasks[id]![state]!.append(event.value)
        }
        
        try! await handlers.createTasks(tasks, withRunID: runID)
    }
}
