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
    
    var calendars: [EKCalendar] {
        eventStore.calendars(for: .event).filter({ $0.allowsContentModifications && !$0.isSubscribed })
    }
    
    var defaultDateInterval: DateInterval {
        let current = Date()
        let defaultStart = Calendar.current.date(byAdding: .year, value: -1, to: current)!
        let defaultEnd = Calendar.current.date(byAdding: .year, value: 1, to: current)!
            
        return .init(start: defaultStart, end: defaultEnd)
    }
    
    public func eventsPredicate(withStart startDate: Date? = nil, end: Date? = nil) -> NSPredicate {
        let eventStore = EKEventStore()
        let interval = eventConfiguration.eventRequestDateInterval() ?? defaultDateInterval
        
        let startDate = startDate ?? interval.start
        let endDate = end ?? interval.end
        let predicate = eventStore.predicateForEvents(withStart: startDate,
                                                      end: endDate,
                                                      calendars: calendars)
        
        return predicate
    }
    
    @discardableResult
    public func enumerateEventsAndReturnsIfExceedsNonProLimit(matching precidate: NSPredicate? = nil, handler: ((EKEvent, @escaping () -> Void) -> Void)? = nil) -> Bool {
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
