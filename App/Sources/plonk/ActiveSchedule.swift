import Foundation

// When a stay-active window is open.
//
// A window is a time of day, an end, and the weekdays it runs on. It is not a
// pair of timers: a Mac that slept through 09:00 and woke at 11:00 never fires
// the start timer, and would sit idle until tomorrow. `contains` is asked
// instead, on a tick and on every wake, so the answer is always derived from
// the clock rather than from having caught a moment.
//
// Minutes from midnight rather than a Date, because the window repeats and a
// Date does not.

struct ActiveSchedule: Codable, Equatable {
    var enabled = false
    var start = 9 * 60
    var end = 18 * 60
    /// Calendar weekday numbers, where Sunday is 1. Monday to Friday by
    /// default: an unqualified 09:00-18:00 would otherwise cover Saturday.
    var days: Set<Int> = [2, 3, 4, 5, 6]

    /// A window whose end is before its start crosses midnight and belongs to
    /// the day it opened on, so 22:00-02:00 on a Monday runs into Tuesday.
    var crossesMidnight: Bool { end < start }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard enabled, start != end else { return false }
        let parts = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        guard let hour = parts.hour, let minute = parts.minute, let weekday = parts.weekday
        else { return false }
        let now = hour * 60 + minute
        guard crossesMidnight else {
            return days.contains(weekday) && now >= start && now < end
        }
        if days.contains(weekday) && now >= start { return true }
        // Still inside yesterday's window; yesterday is the day that had to be
        // selected for it, not today.
        return days.contains(Self.previousWeekday(weekday)) && now < end
    }

    static func previousWeekday(_ weekday: Int) -> Int {
        weekday == 1 ? 7 : weekday - 1
    }

    /// Minutes from midnight as `HH:mm`, for the API and for pickers.
    static func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }

    /// Parses `HH:mm`. Returns nil for anything else, including an hour or a
    /// minute out of range, so a bad value from an agent is refused rather than
    /// silently wrapped.
    static func minutes(fromClock text: String) -> Int? {
        let parts = text.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute)
        else { return nil }
        return hour * 60 + minute
    }
}
