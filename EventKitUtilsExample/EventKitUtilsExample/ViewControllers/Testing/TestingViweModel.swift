//
//  TestingViweModel.swift
//  EventKitUtilsExample
//
//  Created by Kai Shao on 2022/9/8.
//

import Foundation
import EventKitUtils
import EventKit
import UIKitUtils
import os

class TestingViweModel {
    var em: EventManager {
        .shared
    }
    
    let signposter = OSSignposter()
    
    @MainActor
    func run() async {
        await deleteAllCalendarEvents()
        await createNeverEndRepeatTask(info: repeatInfo)
        await testUniqueness()
        await testDeleteFirstAndFuture()
        
        await deleteAllCalendarEvents()
        await createNeverEndRepeatTask(info: repeatInfo)
        await testDeleteSecond()
        
        await createTenRepeatEvents()
        await testIsTenUniqueEvents()
    }
}

private extension TestingViweModel {
    func fetchEvents() -> [EKEvent] {
        em.eventStore.events(matching: em.eventStore.predicateForEvents(withStart: em.config.eventRequestRange.lowerBound, end: em.config.eventRequestRange.upperBound, calendars: [em.eventStore.defaultCalendarForNewEvents!]))
    }
    
    func deleteAllCalendarEvents() async {
        let events = fetchEvents()
        await em.deleteTasks(events)
        
        assert(fetchEvents().count == 0)
    }
    
    var repeatInfo: TaskRepeatingInfo {
        .init(title: "test1", keyResultID: "abc")
    }
    
    func createNeverEndRepeatTask(info: TaskRepeatingInfo, startDate: Date = Date()) async {
        var task = TaskValue(normalizedTitle: info.title)
        var event = EKEvent(baseURL: em.config.eventBaseURL, eventStore: em.eventStore)
        let rule = EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        
        task.keyResultId = info.keyResultID
        task.normalizedStartDate = startDate
        task.normalizedEndDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate)
        
        event.recurrenceRules = [rule]
        event.calendar = em.eventStore.defaultCalendarForNewEvents
        event.assignFromTaskKind(task)
        
        try! await em.saveTask(event)
    }
    
    func testUniqueness() async {
        let tasks = await em.fetchTasks(with: .repeatingInfo(repeatInfo, uniquedById: true))
        assert(tasks.count == 1)
        
        let tasks2 = await em.fetchTasks(with: .repeatingInfo(repeatInfo, uniquedById: false))
        assert(tasks2.uniqued(by: \.normalizedID).count == 1)
    }
    
    func testDeleteFirstAndFuture() async {
        var tasks = await em.fetchTasks(with: .repeatingInfo(repeatInfo, uniquedById: true))
        assert(tasks.count == 1)

        await em.deleteTasks(tasks)
        tasks = await em.fetchTasks(with: .repeatingInfo(repeatInfo, uniquedById: true))
        assert(tasks.isEmpty)
    }
    
    func testDeleteSecond() async {
        var tasks = await em.fetchTasks(with: .repeatingInfo(repeatInfo, uniquedById: false))
        assert(tasks.count >= 365)
        
        let dropped = Array(tasks.dropFirst())
        await em.deleteTasks(dropped)
        tasks = await em.fetchTasks(with: .repeatingInfo(repeatInfo, uniquedById: false))
        assert(tasks.count == 1)
    }
}

extension TestingViweModel {
    func createTenRepeatEvents() async {
        var date = Date()
        
        let id = signposter.makeSignpostID()
        let state = signposter.beginInterval("tvm createTenRepeatEvents", id: id)
        
        defer {
            signposter.endInterval("tvm createTenRepeatEvents", state)
        }
        
        for index in 0..<99 {
            date = Calendar.current.date(byAdding: .hour, value: 1, to: date)!
            let info = TaskRepeatingInfo(title: "repeat \(index)", keyResultID: "abc")
            
            await createNeverEndRepeatTask(info: info, startDate: date)
        }
    }
    
    func testIsTenUniqueEvents() async {
        let id = signposter.makeSignpostID()
        let state = signposter.beginInterval("tvm testIsTenUniqueEvents", id: id)
        
        defer {
            signposter.endInterval("tvm testIsTenUniqueEvents", state)
        }
        
        let tasks = await em.fetchTasks(with: .segment(.incompleted)).uniqued(by: \.normalizedID)
        assert(tasks.count == 100)
    }
}
