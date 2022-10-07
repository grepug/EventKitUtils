//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/9/22.
//

import EventKit

public struct EventEnumerator {
    init(eventStore: EKEventStore, eventConfiguration: EventConfiguration) {
        self.eventStore = eventStore
        self.eventConfiguration = eventConfiguration
    }
    
    public init(eventManager em: EventManager) {
        self.eventStore = em.eventStore
        self.eventConfiguration = em.configuration
    }
    
    var eventStore: EKEventStore
    var eventConfiguration: EventConfiguration
    
    /// The public call site for ``enumerateEventsAndReturnsIfExceedsNonProLimitImpl(matching:handler:)``
    ///
    /// Date interval that enumerates in defaults to the configuration, which is an async method. Therefore this method should be an async too.
    /// - Parameters:
    ///   - dateInterval: the date interval it should enumerate in
    ///   - handler: returns an EKEvent to the function caller each enumeration, and offers a completion handler to stop the enumeration
    /// - Returns: a boolean indicates if the count of events has exceeded the non Pro user's limit
    @discardableResult
    public func enumerateEventsAndReturnsIfExceedsNonProLimit(matching dateInterval: DateInterval? = nil, handler: ((EKEvent, @escaping () -> Void) -> Void)? = nil) async -> Bool {
        let interval: DateInterval
        
        if let dateInterval {
            interval = dateInterval
        } else {
            interval = await eventConfiguration.eventRequestDateInterval() ?? .defaultEventRequestDateInterval
        }
        
        return enumerateEventsAndReturnsIfExceedsNonProLimitImpl(matching: interval, handler: handler)
    }
    
    /// The implementation of enumerating over events
    /// - Parameters:
    ///   - dateInterval: the date interval it should enumerate in
    ///   - handler: returns an EKEvent to the function caller each enumeration, and offers a completion handler to stop the enumeration
    /// - Returns: a boolean indicates if the count of events has exceeded the non Pro user's limit
    private func enumerateEventsAndReturnsIfExceedsNonProLimitImpl(matching dateInterval: DateInterval = .defaultEventRequestDateInterval, handler: ((EKEvent, @escaping () -> Void) -> Void)? = nil) -> Bool {
        var enumeratedRepeatingInfoSet: Set<TaskRepeatingInfo> = []
        var exceededNonProLimit = false

        let predicate = dateInterval.eventPredicate()
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
                    pointer.pointee = true
                }
            }
            
            handler?(event) {
                pointer.pointee = true
            }
        }
        
        return exceededNonProLimit
    }
}

extension DateInterval {
    func eventPredicate() -> NSPredicate {
        let eventStore = EKEventStore()
        let calendars = eventStore.calendars(for: .event).filter({ $0.allowsContentModifications && !$0.isSubscribed })
        
        let predicate = eventStore.predicateForEvents(withStart: start,
                                                      end: end,
                                                      calendars: calendars)
        
        return predicate
    }
    
    public static var defaultEventRequestDateInterval: Self {
        let current = Date()
        let defaultStart = Calendar.current.date(byAdding: .year, value: -1, to: current)!
        let defaultEnd = Calendar.current.date(byAdding: .year, value: 1, to: current)!
            
        return .init(start: defaultStart, end: defaultEnd)
    }
}
