import Foundation

// The /awake route and the keep-awake half of /state.

extension Router {
    func handleAwake(body: [String: Any], respond: @escaping (HTTPResponse) -> Void) {
        let on = (body["on"] as? Bool) ?? !awake.requested
        let until: Date?
        switch Self.deadline(in: body) {
        case .success(let date): until = date
        case .failure(let invalid): return respond(invalid.response)
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
