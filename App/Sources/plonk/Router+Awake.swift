import Foundation

// The /awake route and the keep-awake half of /state.
//
// The route starts and ends sessions and picks the level they run at. The
// schedule and the watched apps are settings rather than sessions, so they are
// edited on the page and only reported here.

extension Router {
    func handleAwake(body: [String: Any], respond: @escaping (HTTPResponse) -> Void) {
        let on = (body["on"] as? Bool) ?? !awake.wants
        let until: Date?
        switch Self.deadline(in: body) {
        case .success(let date): until = date
        case .failure(let invalid): return respond(invalid.response)
        }
        // The level is a setting, not a property of this session: an agent that
        // asks to be shown as available is answering the same question the
        // toggle on the page answers, and the next session inherits it.
        if let available = body["available"] as? Bool, available != store.config.awakeAvailable {
            store.update { $0.awakeAvailable = available }
        }
        if let error = awake.set(on, minutes: (body["minutes"] as? NSNumber)?.intValue,
                                 until: until, pid: (body["pid"] as? NSNumber)?.intValue) {
            respond(.badRequest(error))
            return
        }
        // Neither a missing Accessibility grant nor the battery rule is an
        // error: the request was understood, and "status" says what actually
        // happened.
        respond(.ok(["ok": true, "awake": awake.isOn, "available": awake.isAvailable,
                     "status": String(localized: awake.statusText)]))
    }

    func awakeState() -> [String: Any] {
        let schedule = awake.schedule
        return [
            "requested": awake.wants,
            "status": String(localized: awake.statusText),
            "power": awake.isOnAC ? "ac" : "battery",
            "available": store.config.awakeAvailable,
            "available_now": awake.isAvailable,
            "accessibility_granted": awake.isTrusted,
            "allow_on_battery": awake.allowOnBattery,
            "auto_while_charging": awake.autoWhileCharging,
            "keep_display_on": awake.keepDisplayOn,
            "lid_closed": store.config.awakeLidClosed,
            "session_ends": awake.sessionEnd.map { ISO8601DateFormatter().string(from: $0) } ?? "",
            "bound_pid": awake.boundPID ?? 0,
            "apps_enabled": store.config.awakeAppsEnabled,
            "apps": awake.apps,
            "schedule": [
                "enabled": schedule.enabled,
                "from": AwakeSchedule.clock(schedule.start),
                "to": AwakeSchedule.clock(schedule.end),
                // Weekday numbers, Sunday is 1, as Calendar reports them.
                "days": schedule.days.sorted(),
            ] as [String: Any],
        ]
    }
}
