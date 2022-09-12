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
        
        try! await Task.delayed(byTimeInterval: 3) {
//            await self.createNeverEndRepeatTask(info: self.repeatInfo)
//            await self.testUniqueness()
//            await self.testDeleteFirstAndFuture()
//
//            await self.deleteAllCalendarEvents()
//            await self.createNeverEndRepeatTask(info: self.repeatInfo)
//            await self.testDeleteSecond()
            
            await self.createTenRepeatEvents()
            await self.testIsTenUniqueEvents()
        }.value
    }
}

private extension TestingViweModel {
    func fetchEvents() async -> [EKEvent] {
        let config = em.config
        
        return em.eventStore.events(matching: em.eventStore.predicateForEvents(withStart: config.eventRequestRange.lowerBound, end: config.eventRequestRange.upperBound, calendars: [em.eventStore.defaultCalendarForNewEvents!]))
    }
    
    func deleteAllCalendarEvents() async {
        let events = await fetchEvents()
        await em.deleteTasks(events)
        
        let events2 = await fetchEvents()
        assert(events2.count == 0)
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
        let tasks = await em.fetchTasks(with: .repeatingInfo(repeatInfo), onlyFirst: true)
        assert(tasks.count == 1)
        
        let tasks2 = await em.fetchTasks(with: .repeatingInfo(repeatInfo), onlyFirst: false)
        assert(tasks2.uniqued(by: \.normalizedID).count == 1)
    }
    
    func testDeleteFirstAndFuture() async {
        let tasks = await em.fetchTasks(with: .repeatingInfo(repeatInfo), onlyFirst: true)
        assert(tasks.count == 1)

        await em.deleteTasks(tasks)
        
        try! await Task.delayed(byTimeInterval: 3) {
            let tasks = await self.em.fetchTasks(with: .repeatingInfo(self.repeatInfo), onlyFirst: true)
            assert(tasks.isEmpty)
        }.value
    }
    
    func testDeleteSecond() async {
        let tasks = await em.fetchTasks(with: .repeatingInfo(repeatInfo), onlyFirst: false)
        assert(tasks.count >= 360)
        
        let dropped = Array(tasks.dropFirst())
        await em.deleteTasks(dropped)
        
        try! await Task.delayed(byTimeInterval: 3) {
            let tasks = await self.em.fetchTasks(with: .repeatingInfo(self.repeatInfo), onlyFirst: false)
            assert(tasks.count == 1)
        }.value
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
        
        for index in 0..<100 {
            date = Calendar.current.date(byAdding: .hour, value: 1, to: date)!
            let info = TaskRepeatingInfo(title: "repeat \(index)", keyResultID: "abc")
            
            await createNeverEndRepeatTask(info: info, startDate: date)
        }
        
//        em.reloadCaches.send()
        await em.cacheManager.makeCache()
//        try! await Task.sleep(nanoseconds: 1_000_000_000 * 1)
    }
    
    func testIsTenUniqueEvents() async {
        let id = signposter.makeSignpostID()
        let state = signposter.beginInterval("tvm testIsTenUniqueEvents", id: id)
        
        defer {
            signposter.endInterval("tvm testIsTenUniqueEvents", state)
        }
        
        if await em.cacheManager.isPending == false {
            let tasks = await self.em.fetchTasks(with: .segment(.incompleted), onlyFirst: true)
            assert(tasks.count == 100)
        }
    }
}

extension Task where Failure == Error {
    @discardableResult
    static func delayed(
        byTimeInterval delayInterval: TimeInterval,
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable () async throws -> Success
    ) -> Task {
        Task(priority: priority) {
            let delay = UInt64(delayInterval * 1_000_000_000)
            try await Task<Never, Never>.sleep(nanoseconds: delay)
            return try await operation()
        }
    }
}
