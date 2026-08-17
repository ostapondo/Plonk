import Foundation
import Testing
@testable import plonk

// When a stay-active window is open. The calendar is injected so the answers do
// not depend on where the test runs, and the dates below are chosen for their
// weekdays: 2026-08-10 is a Monday, 2026-08-15 a Saturday.

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func at(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: iso)!
}

/// Weekdays only, 09:00 to 18:00.
private func workdays() -> ActiveSchedule {
    var schedule = ActiveSchedule()
    schedule.enabled = true
    return schedule
}

struct ActiveScheduleTests {

    @Test func offWhenNotEnabled() {
        var schedule = workdays()
        schedule.enabled = false
        #expect(!schedule.contains(at("2026-08-10T12:00:00Z"), calendar: utc))
    }

    @Test func openInsideTheWindowOnAWorkday() {
        #expect(workdays().contains(at("2026-08-10T12:00:00Z"), calendar: utc))
    }

    @Test func shutBeforeAndAfter() {
        #expect(!workdays().contains(at("2026-08-10T08:59:00Z"), calendar: utc))
        #expect(!workdays().contains(at("2026-08-10T18:30:00Z"), calendar: utc))
    }

    /// The end is exclusive: at 18:00 the window is over, not still open for
    /// one more minute.
    @Test func theEndIsExclusive() {
        #expect(workdays().contains(at("2026-08-10T17:59:00Z"), calendar: utc))
        #expect(!workdays().contains(at("2026-08-10T18:00:00Z"), calendar: utc))
    }

    /// The default day set is the reason an unqualified 09:00-18:00 does not
    /// cover the weekend.
    @Test func shutAtTheWeekend() {
        #expect(!workdays().contains(at("2026-08-15T12:00:00Z"), calendar: utc))
    }

    // MARK: - Crossing midnight

    /// 22:00 to 02:00 on a Monday has to still be open at one in the morning on
    /// Tuesday, which a plain `start <= now && now < end` gets wrong by
    /// describing an empty window.
    @Test func aWindowThatCrossesMidnightRunsIntoTheNextDay() {
        var schedule = workdays()
        schedule.start = 22 * 60
        schedule.end = 2 * 60
        #expect(schedule.crossesMidnight)
        #expect(schedule.contains(at("2026-08-10T23:00:00Z"), calendar: utc))
        #expect(schedule.contains(at("2026-08-11T01:00:00Z"), calendar: utc))
        #expect(!schedule.contains(at("2026-08-11T03:00:00Z"), calendar: utc))
    }

    /// The small hours belong to the day the window opened on. Saturday is not
    /// selected, so Saturday 01:00 is Friday's window and open; Sunday 01:00 is
    /// Saturday's and is not.
    @Test func theSmallHoursBelongToTheDayTheWindowOpened() {
        var schedule = workdays()
        schedule.start = 22 * 60
        schedule.end = 2 * 60
        #expect(schedule.contains(at("2026-08-15T01:00:00Z"), calendar: utc))
        #expect(!schedule.contains(at("2026-08-16T01:00:00Z"), calendar: utc))
    }

    /// Two equal times describe no window rather than a whole day. Saying so
    /// out loud beats leaving it to whichever comparison ran first.
    @Test func equalTimesAreNoWindowAtAll() {
        var schedule = workdays()
        schedule.start = 9 * 60
        schedule.end = 9 * 60
        #expect(!schedule.contains(at("2026-08-10T09:00:00Z"), calendar: utc))
        #expect(!schedule.contains(at("2026-08-10T12:00:00Z"), calendar: utc))
    }

    // MARK: - Clock text

    @Test func clockTextRoundTrips() {
        #expect(ActiveSchedule.clock(0) == "00:00")
        #expect(ActiveSchedule.clock(9 * 60 + 5) == "09:05")
        #expect(ActiveSchedule.clock(23 * 60 + 59) == "23:59")
        #expect(ActiveSchedule.minutes(fromClock: "09:05") == 9 * 60 + 5)
        #expect(ActiveSchedule.minutes(fromClock: "00:00") == 0)
    }

    @Test func badClockTextIsRefused() {
        #expect(ActiveSchedule.minutes(fromClock: "24:00") == nil)
        #expect(ActiveSchedule.minutes(fromClock: "09:60") == nil)
        #expect(ActiveSchedule.minutes(fromClock: "9") == nil)
        #expect(ActiveSchedule.minutes(fromClock: "nine") == nil)
        #expect(ActiveSchedule.minutes(fromClock: "-1:00") == nil)
    }

    @Test func theDayBeforeSundayIsSaturday() {
        #expect(ActiveSchedule.previousWeekday(1) == 7)
        #expect(ActiveSchedule.previousWeekday(2) == 1)
    }
}
