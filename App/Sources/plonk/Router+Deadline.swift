import Foundation

// Turning what someone typed into a moment in time.
//
// Kept out of Router, which owns the route table rather than parsers. /awake
// takes a deadline; "until 17:00" is the same question wherever it is asked
// from.

extension Router {
    /// The optional "until" of a request body: nil when absent, .failure with
    /// the response to send when it does not parse.
    static func deadline(in body: [String: Any]) -> Result<Date?, InvalidDeadline> {
        guard let raw = trimmedName(body["until"]) else { return .success(nil) }
        guard let parsed = parseDeadline(raw) else { return .failure(InvalidDeadline()) }
        return .success(parsed)
    }

    struct InvalidDeadline: Error {
        var response: HTTPResponse {
            .badRequest("\"until\" must be a time of day like \"17:00\" or an "
                        + "ISO-8601 timestamp like \"2026-08-08T17:00:00Z\"")
        }
    }

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
