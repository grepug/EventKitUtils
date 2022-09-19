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
    init(eventStore: EKEventStore, eventConfiguration: EventConfiguration, handlers: CacheHandlers, currentRunID: String? = nil, uniquedIDs: Set<String> = [], isPending: Bool = false) {
        self.eventStore = eventStore
        self.eventConfiguration = eventConfiguration
        self.handlers = handlers
        self.currentRunID = currentRunID
        self.uniquedIDs = uniquedIDs
        self.isPending = isPending
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
        
        try? await handlers.clean()
        
        let runID = UUID().uuidString
        
        await makeCacheImpl(runID: runID)
        
        isPending = false
    }
    
    private func makeCacheImpl(runID: String) async {
        var tasks: [TaskValue] = []
        var uniquedIDs: Set<String> = []
        
        enumerateEventsAndReturnsIfExceedsNonProLimit { event, completion in
            let isFirst = !uniquedIDs.contains(event.normalizedID)
            uniquedIDs.insert(event.normalizedID)
            var task = event.value
            task.isFirstRecurrence = isFirst
            tasks.append(task)
        }
        
        try! await handlers.createTasks(tasks, withRunID: runID)
    }
}

extension CacheManager {
    func eventsPredicate() -> NSPredicate {
        let eventStore = EKEventStore()
        let calendars = eventStore.calendars(for: .event).filter({ $0.allowsContentModifications && !$0.isSubscribed })
        let predicate = eventStore.predicateForEvents(withStart: eventConfiguration.eventRequestRange.lowerBound,
                                                      end: eventConfiguration.eventRequestRange.upperBound,
                                                      calendars: calendars)
        
        return predicate
    }
    
    @discardableResult
    func enumerateEventsAndReturnsIfExceedsNonProLimit(matching precidate: NSPredicate? = nil, handler: ((EKEvent, @escaping () -> Void) -> Void)? = nil) -> Bool {
//        var deferredAction: (() -> Void)?
//
//        if #available(iOS 15.0, *) {
//            let key: StaticString = "enumerateEventsAndReturnsIfExceedsNonProLimit"
//            let signpostID = Self.signposter.makeSignpostID()
//            let state = Self.signposter.beginInterval(key, id: signpostID)
//
//            deferredAction = {
//                Self.signposter.endInterval(key, state)
//            }
//        }
//
//        defer {
//            deferredAction?()
//        }
        
        var enumeratedRepeatingInfoSet: Set<TaskRepeatingInfo> = []
        var exceededNonProLimit = false
        
        let predicate = precidate ?? eventsPredicate()
        let config = eventConfiguration
        
        eventStore.enumerateEvents(matching: predicate) { event, pointer in
            guard event.url?.host == config.eventBaseURL.host else {
                return
            }
            
            if let nonProLimit = config.maxNonProLimit {
                if !exceededNonProLimit {
                    enumeratedRepeatingInfoSet.insert(event.repeatingInfo)
                }
                
                if enumeratedRepeatingInfoSet.count == nonProLimit {
                    exceededNonProLimit = true
                }
            }
            
            handler?(event) {
                pointer.pointee = true
            }
        }
        
        return exceededNonProLimit
    }
}

/// 参考：
/// https://forums.swift.org/t/taskgroup-vs-an-array-of-tasks/53931/2
extension Array where Element == Task<Void, Never> {
    func awaitAll() async {
        await withTaskGroup(of: Void.self) { group in
            for task in self {
                group.addTask {
                    await task.value
                }
            }
        }
    }
}
