//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/9/11.
//

import Foundation
import Combine
import EventKit

actor CacheManager {
    init(eventStore: EKEventStore, config: TaskConfig, handlers: CacheHandlers, currentRunID: String? = nil, uniquedIDs: Set<String> = []) {
        self.eventStore = eventStore
        self.config = config
        self.handlers = handlers
        self.currentRunID = currentRunID
        self.uniquedIDs = uniquedIDs
    }
    
    var eventStore: EKEventStore
    var config: TaskConfig
    var handlers: CacheHandlers
    var currentRunID: String?
    var uniquedIDs: Set<String> = []
}

extension CacheManager {
    func makeCache() async {
        Task {
            await handlers.clean()
        }
        
        let date = Date()
        let runID = UUID().uuidString
        self.currentRunID = runID
        
        await handlers.createRun(id: runID, at: date)
        await makeCacheImpl(runID: runID)
    }
    
    func insertIdToUniqueIds(_ id: String) {
        uniquedIDs.insert(id)
    }
    
    private func makeCacheImpl(runID: String) async {
        var runState = CacheHandlersRunState.inProgress
        var _tasks: [Task<Void, Never>] = []
        
        enumerateEventsAndReturnsIfExceedsNonProLimit { [weak self] event, completion in
            guard let self = self else {
                completion()
                return
            }
            
            let _task = Task {
                /// 当 `runID` 变化后，停止该遍历
                print("runID", await self.currentRunID!, runID)
                
                guard await self.currentRunID == runID else {
                    await self.handlers.setRunState(.stopped, withID: runID)
                    completion()
                    return
                }
                
                let isFirst = !(await self.uniquedIDs.contains(event.normalizedID))
                await self.insertIdToUniqueIds(event.normalizedID)
                
                await self.handlers.createTask(event.value,
                                               isFirst: isFirst,
                                               withRunID: runID)
            }
            
            _tasks.append(_task)
        }
        
        
        if runState != .stopped {
            runState = .completed
        }
        
        await _tasks.awaitAll()
        await handlers.setRunState(runState, withID: runID)
    }
}

extension CacheManager {
    func eventsPredicate() -> NSPredicate {
        let eventStore = EKEventStore()
        let calendars = eventStore.calendars(for: .event).filter({ $0.allowsContentModifications && !$0.isSubscribed })
        let predicate = eventStore.predicateForEvents(withStart: config.eventRequestRange.lowerBound,
                                                      end: config.eventRequestRange.upperBound,
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
        let config = config
        
        eventStore.enumerateEvents(matching: predicate) { event, pointer in
            guard event.url?.host == config.eventBaseURL.host else {
                return
            }
            
            if let nonProLimit = config.maxNonProLimit() {
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
