import Foundation

// Turning what someone typed into a moment in time.
//
// Kept out of Router, which is over the line limit and owns routes rather than
// parsers. /awake is the only route that takes a deadline today; keep-awake
// "until 17:00" is the same question wherever it is asked from.

extension Router {
    /// "17:00" or "17:00:00" is the next such moment — today when it is still
    /// ahead, tomorrow when it has passed, which is what someone setting an
    /// alarm at midnight means. An ISO-8601 timestamp is taken as written.
    static func parseDeadline(_ raw: String, now: Date = Date(),
                              calendar: Calendar = .current) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: trimmed) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: trimmed) { return date }

        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard (2...3).contains(parts.count) else { return nil }
        let numbers = parts.compactMap(Int.init)
        guard numbers.count == parts.count else { return nil }
        let (hour, minute) = (numbers[0], numbers[1])
        let second = numbers.count == 3 ? numbers[2] : 0
        guard (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else { return nil }

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = second
        guard let today = calendar.date(from: components) else { return nil }
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
    }
}
