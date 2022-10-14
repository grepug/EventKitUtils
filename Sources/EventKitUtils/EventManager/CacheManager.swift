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
    public var handlers: CacheHandlers
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
        
        try? await handlers.cleanup(exceptRunID: runID)
        await makeCacheImpl(runID: runID)
        
        isPending = false
    }
    
    private var eventEnumerator: EventEnumerator {
        .init(eventStore: eventStore, eventConfiguration: eventConfiguration)
    }
    
    private func makeCacheImpl(runID: String) async {
        var tasks: CacheHandlersTaskValuesDict = [:]
        let eventStore = EKEventStore()
        
        await eventEnumerator.enumerateEventsAndReturnsIfExceedsNonProLimit(eventStore: eventStore) { event, completion in
            let repeatingInfo = event.repeatingInfo
            let state = event.state
            
            if tasks[repeatingInfo] == nil {
                tasks[repeatingInfo] = [:]
            }
            
            if tasks[repeatingInfo]![state] == nil {
                tasks[repeatingInfo]![state] = []
            }
            
            tasks[repeatingInfo]![state]!.append(event.value)
        }
        
        try! await handlers.createTasks(tasks, withRunID: runID)
    }
}
