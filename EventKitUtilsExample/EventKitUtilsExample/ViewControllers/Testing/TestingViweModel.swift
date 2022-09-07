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

class TestingViweModel {
    var em: EventManager {
        .shared
    }
    
    @MainActor
    func run() async {
        await deleteAllCalendarEvents()
        await createNeverEndRepeatTask()
        await testUniqueness()
        await testDeleteFirstAndFuture()
        
        await deleteAllCalendarEvents()
        await createNeverEndRepeatTask()
        await testDeleteSecond()
    }
}

private extension TestingViweModel {
    func deleteAllCalendarEvents() async {
        let events = em.eventStore.events(matching: em.eventStore.predicateForEvents(withStart: em.config.eventRequestRange.lowerBound, end: em.config.eventRequestRange.upperBound, calendars: [em.eventStore.defaultCalendarForNewEvents!]))
        
        await em.deleteTasks(events)
    }
    
    var repeatInfo: TaskRepeatingInfo {
        .init(title: "test1", keyResultID: "abc")
    }
    
    func createNeverEndRepeatTask() async {
        var task = TaskValue(normalizedTitle: repeatInfo.title)
        var event = EKEvent(baseURL: em.config.eventBaseURL, eventStore: em.eventStore)
        let rule = EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        
        task.keyResultId = repeatInfo.keyResultID
        task.normalizedStartDate = Date()
        task.normalizedEndDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
        
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
        assert(tasks.count == 366)
        
        let dropped = Array(tasks.dropFirst())
        await em.deleteTasks(dropped)
        tasks = await em.fetchTasks(with: .repeatingInfo(repeatInfo, uniquedById: false))
        assert(tasks.count == 1)
    }
}
