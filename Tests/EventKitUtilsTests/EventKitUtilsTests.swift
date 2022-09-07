import XCTest
@testable import EventKitUtils
import EventKit

final class EventKitUtilsTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        let store = EKEventStore()
        let events = store.calendars(for: .event)
        
        XCTAssert(EKEventStore.authorizationStatus(for: .event) == .denied)
        XCTAssert(events.count == 0)
    }
}
