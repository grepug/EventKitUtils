//
//  File.swift
//  
//
//  Created by Kai Shao on 2022/9/11.
//

import Foundation
import EventKit

protocol EventEnumeration: AnyObject {
    var eventStore: EKEventStore { get }
    
    func taskConfig() -> TaskConfig
}

extension EventEnumeration {
    func eventsPredicate() -> NSPredicate {
        let config = taskConfig()
        let eventStore = EKEventStore()
        let calendars = eventStore.calendars(for: .event).filter({ $0.allowsContentModifications && !$0.isSubscribed })
        let predicate = eventStore.predicateForEvents(withStart: config.eventRequestRange.lowerBound,
                                                      end: config.eventRequestRange.upperBound,
                                                      calendars: calendars)
        
        return predicate
    }
}

extension EventEnumeration {
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
        let config = taskConfig()
        
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
