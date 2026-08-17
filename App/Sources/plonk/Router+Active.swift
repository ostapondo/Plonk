import Foundation

// The /active route and the stay-active half of /state.
//
// The route starts and ends sessions, the way /awake does. The schedule and the
// watched apps are settings rather than sessions, so they are edited on the
// page and only reported here.

extension Router {
    func handleActive(body: [String: Any], respond: @escaping (HTTPResponse) -> Void) {
        let on = (body["on"] as? Bool) ?? !active.wants
        var until: Date?
        if let raw = trimmedName(body["until"]) {
            guard let parsed = Self.parseDeadline(raw) else {
                respond(.badRequest("\"until\" must be a time of day like \"17:00\" or an "
                                    + "ISO-8601 timestamp like \"2026-08-08T17:00:00Z\""))
                return
            }
            until = parsed
        }
        if let error = active.set(on, minutes: (body["minutes"] as? NSNumber)?.intValue,
                                  until: until) {
            respond(.badRequest(error))
            return
        }
        // Not an error when Accessibility is missing or the battery rule holds
        // it back: the request was understood, and "status" says what actually
        // happened, which is the same contract /awake has.
        respond(.ok(["ok": true, "active": active.isOn,
                     "status": String(localized: active.statusText)]))
    }

    func activeState() -> [String: Any] {
        let schedule = active.schedule
        return [
            "requested": active.wants,
            "status": String(localized: active.statusText),
            "power": active.isOnAC ? "ac" : "battery",
            "allow_on_battery": active.allowOnBattery,
            "accessibility_granted": active.isTrusted,
            "session_ends": active.sessionEnd.map { ISO8601DateFormatter().string(from: $0) } ?? "",
            "apps": active.apps,
            "schedule": [
                "enabled": schedule.enabled,
                "from": ActiveSchedule.clock(schedule.start),
                "to": ActiveSchedule.clock(schedule.end),
                // Weekday numbers, Sunday is 1, as Calendar reports them.
                "days": schedule.days.sorted(),
            ] as [String: Any],
        ]
    }
}
