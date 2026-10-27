import XCTest

final class ReminderTests: XCTestCase {
    func testPreferredHourIsClampedMedian() {
        XCTAssertEqual(Reminders.preferredHour(from: []), 19)
        XCTAssertEqual(Reminders.preferredHour(from: [8, 20, 21, 22, 12]), 20)
        XCTAssertEqual(Reminders.preferredHour(from: [1, 2, 3]), 9)
        XCTAssertEqual(Reminders.preferredHour(from: [23, 23]), 21)
    }

    func testIntervalAimsForHundredPhotosWithinWeekToMonth() {
        XCTAssertEqual(Reminders.interval(photosPerDay: 0), 30)
        XCTAssertEqual(Reminders.interval(photosPerDay: 0.5), 30)
        XCTAssertEqual(Reminders.interval(photosPerDay: 10), 10)
        XCTAssertEqual(Reminders.interval(photosPerDay: 50), 7)
    }

    func testFireDateSnapsToHour() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 22, minute: 15))!
        let expected = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 19))!
        XCTAssertEqual(Reminders.fireDate(daysFromNow: 7, hour: 19, now: now), expected)
    }
}
