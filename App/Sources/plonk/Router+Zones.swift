import AppKit

// The /zones routes, which edit the sets, and /layout/zone, which puts a window
// in one of them.
//
// Assignments are stored per display UUID and agents work in screen indices, so
// every route here goes through ScreenIdentity rather than touching the config
// keys itself. See ScreenIdentity for why the index alone will not do.

extension Router {
    func saveZoneSetRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let name = Self.trimmedName(body["name"]), let raw = body["zones"] as? [[String: Any]] else {
            return .badRequest("body must be {\"name\", \"zones\": [{x,y,w,h}], \"screen\"?, \"gap\"?}")
        }
        let zones = raw.compactMap { ZoneRect(dict: $0) }
        guard !zones.isEmpty, zones.count == raw.count else {
            return .badRequest("every zone needs x,y,w,h within 0..1, with w and h above 0")
        }
        // Said rather than dropped: a caller that named a zone "2" would
        // otherwise read ok and find the name gone.
        if let refused = raw.compactMap({ $0["name"] as? String }).first(where: ZoneRect.isRefusedName) {
            return .badRequest("\"\(refused)\" cannot be a zone's name: a number already means the zone in that place")
        }
        if let taken = ZoneGeometry.duplicateName(in: zones) {
            return .badRequest("zone names must be unique within a set, ignoring case; \"\(taken)\" is used twice")
        }
        // A gap given is the set's own; null or absent leaves whatever it had,
        // so a client that only knows zones does not silently reset it.
        var gap: Double??
        if body["gap"] is NSNull {
            gap = .some(nil)
        } else if let number = body["gap"] as? NSNumber {
            guard number.doubleValue >= 0, number.doubleValue <= Config.gapLimit else {
                return .badRequest("gap must be 0...\(Int(Config.gapLimit)) points")
            }
            gap = .some(number.doubleValue)
        } else if body["gap"] != nil {
            return .badRequest("gap must be a number of points, or null for the default")
        }
        store.update {
            $0.zoneSets[name] = zones
            if let gap { $0.zoneSetGaps[name] = gap }
            if let screen = (body["screen"] as? NSNumber)?.intValue {
                $0.assignZoneSet(name, forKeys: ScreenIdentity.keys(forIndex: screen))
            }
        }
        didChangeZones?()
        var reply: [String: Any] = ["ok": true, "saved": name, "zones": zones.count]
        reply["gap"] = store.config.zoneSetGaps[name] ?? NSNull()
        return .ok(reply)
    }

    func assignZoneSetRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let screen = (body["screen"] as? NSNumber)?.intValue else {
            return .badRequest("body must include screen; omit name for the default set "
                               + "(\(BuiltinZoneSets.defaultName)), pass \"edge\" for edge snapping")
        }
        let requested = (body["name"] as? String)?.trimmingCharacters(in: .whitespaces)
        let assignment: String?
        switch requested {
        case nil:
            assignment = nil
        case let name? where name.isEmpty || name.lowercased() == "edge":
            assignment = ""
        case let name?:
            guard store.config.zoneSets[name] != nil || BuiltinZoneSets.all[name] != nil else {
                return .notFound("no zone set named \"\(name)\"")
            }
            assignment = name
        }
        store.update { $0.assignZoneSet(assignment, forKeys: ScreenIdentity.keys(forIndex: screen)) }
        didChangeZones?()
        return .ok(["ok": true])
    }

    func deleteZoneSetRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let name = Self.trimmedName(body["name"]) else {
            return .badRequest("body must include name")
        }
        // Built-ins are not deletable, and they are not in zoneSets, so this
        // guard covers both cases with one answer.
        guard store.config.zoneSets[name] != nil else {
            return .notFound("no zone set named \"\(name)\"")
        }
        store.update { $0.forgetZoneSet(named: name) }
        didChangeZones?()
        return .ok(["ok": true, "deleted": name])
    }

    /// Zones are addressed by the number the drag overlay draws on them, so
    /// "the middle zone" is whatever the user sees as 2 in a three-zone set,
    /// or by the name the set gives one, so "chat" is wherever chat is today.
    func placeInZoneRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let app = Self.trimmedName(body["app"]), let wanted = body["zone"],
              wanted is NSNumber || wanted is String else {
            return .badRequest("body must be {\"app\", \"zone\": 1-based index or name, \"title\"?, \"screen\"?}")
        }
        let title = body["title"] as? String
        guard let screen = (body["screen"] as? NSNumber)?.intValue
                ?? windows.screenIndex(ofApp: app, titleContains: title) else {
            return .notFound("app \"\(app)\" is not running")
        }
        let zones = store.config.zones(forKeys: ScreenIdentity.keys(forIndex: screen))
        guard !zones.isEmpty else {
            return .badRequest("screen \(screen) uses edge snapping, so it has no numbered zones")
        }
        guard let index = Self.zoneIndex(wanted, in: zones) else {
            let names = zones.compactMap(\.name)
            let named = names.isEmpty ? "" : ", named " + names.map { "\"\($0)\"" }.joined(separator: ", ")
            return .badRequest("screen \(screen) has zones 1...\(zones.count)\(named)")
        }
        let error = windows.place(app: app, titleContains: title, screen: screen,
                                  frac: zones[index].frac,
                                  gap: CGFloat(store.config.zoneGap(forKeys: ScreenIdentity.keys(forIndex: screen))))
        if let error { return .failed(error) }
        var reply: [String: Any] = ["ok": true, "app": app, "screen": screen, "zone": index + 1, "zones": zones.count]
        if let name = zones[index].name { reply["name"] = name }
        return .ok(reply)
    }

    /// The zone a request means: a number as the overlay draws it, the same
    /// number as text, or a name the set gives a zone. Nil for any of those
    /// the set does not have.
    static func zoneIndex(_ wanted: Any, in zones: [ZoneRect]) -> Int? {
        let text = trimmedName(wanted)
        if let number = (wanted as? NSNumber)?.intValue ?? text.flatMap(Int.init) {
            // Bounded before anything is subtracted from it: a body can hold
            // any integer, and the smallest one would trap.
            return number >= 1 && zones.indices.contains(number - 1) ? number - 1 : nil
        }
        return text.flatMap { ZoneGeometry.index(named: $0, in: zones) }
    }
}
