//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/9/11.
//

import Combine
import Foundation
import EventKit

class CacheManager2 {
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
    @Published var currentRunID: String?
    var uniquedIDs: Set<String> = []
}

extension CacheManager2 {
    func makeCache() -> AnyPublisher<String, Never> {
        let date = Date()
        let runID = UUID().uuidString
        self.currentRunID = runID
        
        return handlers.createRunPublisher(id: runID, at: date)
            .flatMap { self.makeCacheImpl(runID: runID) }
            .flatMap { state in
                self.handlers.setRunStatePublisher(state, withID: runID)
            }
            .map { _ in runID }
            .eraseToAnyPublisher()
    }
    
    func makeCacheImpl(runID: String) -> AnyPublisher<CacheHandlersRunState, Never> {
        var runState = CacheHandlersRunState.inProgress
        var publishers: [Future<Void, Never>] = []
        uniquedIDs.removeAll()
        
        self.enumerateEventsAndReturnsIfExceedsNonProLimit { event, completion in
            guard runID == self.currentRunID else {
                runState = .stopped
                completion()
                return
            }
            
            let isFirst = !self.uniquedIDs.contains(event.normalizedID)
            self.uniquedIDs.insert(event.normalizedID)
            
            if isFirst{
                print("isFirst!", isFirst, runID, event.normalizedTitle)
            }
            
            publishers.append(
                self.handlers.createTaskPublisher(event.value,
                                                  isFirst: isFirst,
                                                  withRunID: runID)
            )
        }
        
        if runState != .stopped {
            runState = .completed
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { _ in runState }
            .eraseToAnyPublisher()
    }
}

extension CacheManager2 {
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

struct ZipMany<Element, Failure>: Publisher where Failure: Error {
    typealias Output = [Element]

    private let underlying: AnyPublisher<Output, Failure>

    init<T: Publisher>(publishers: [T]) where T.Output == Element, T.Failure == Failure {
        let zipped: AnyPublisher<[T.Output], T.Failure>? = publishers.reduce(nil) { result, publisher in
            if let result = result {
                return publisher.zip(result).map { element, array in
                    array + [element]
                }.eraseToAnyPublisher()
            } else {
                return publisher.map { [$0] }.eraseToAnyPublisher()
            }
        }
        underlying = zipped ?? Empty(completeImmediately: false)
            .eraseToAnyPublisher()
    }

    func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        underlying.receive(subscriber: subscriber)
    }
}
