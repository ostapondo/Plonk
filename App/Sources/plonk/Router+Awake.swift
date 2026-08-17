import Foundation

// The /awake route and the keep-awake half of /state.

extension Router {
    func handleAwake(body: [String: Any], respond: @escaping (HTTPResponse) -> Void) {
        let on = (body["on"] as? Bool) ?? !awake.requested
        var until: Date?
        if let raw = trimmedName(body["until"]) {
            guard let parsed = Self.parseDeadline(raw) else {
                respond(.badRequest("\"until\" must be a time of day like \"17:00\" or an "
                                    + "ISO-8601 timestamp like \"2026-08-08T17:00:00Z\""))
                return
            }
            until = parsed
        }
        if let error = awake.set(on, minutes: (body["minutes"] as? NSNumber)?.intValue,
                                 until: until, pid: (body["pid"] as? NSNumber)?.intValue) {
            respond(.badRequest(error))
            return
        }
        respond(.ok(["ok": true, "awake": awake.isOn, "status": String(localized: awake.statusText)]))
    }

    func awakeState() -> [String: Any] {
        [
            "requested": awake.requested,
            "status": String(localized: awake.statusText),
            "power": awake.isOnAC ? "ac" : "battery",
            "allow_on_battery": awake.allowOnBattery,
            "auto_while_charging": awake.autoWhileCharging,
            "keep_display_on": awake.keepDisplayOn,
            "session_ends": awake.sessionEnd.map { ISO8601DateFormatter().string(from: $0) } ?? "",
            "bound_pid": awake.boundPID ?? 0,
        ]
    }
}
