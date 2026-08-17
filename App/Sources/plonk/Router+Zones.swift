import AppKit

// The /zones routes, which edit the sets, and /layout/zone, which puts a window
// in one of them.
//
// Assignments are stored per display UUID and agents work in screen indices, so
// every route here goes through ScreenIdentity rather than touching the config
// keys itself. See ScreenIdentity for why the index alone will not do.

extension Router {
    func saveZoneSetRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let name = trimmedName(body["name"]), let raw = body["zones"] as? [[String: Any]] else {
            return .badRequest("body must be {\"name\", \"zones\": [{x,y,w,h}], \"screen\"?}")
        }
        let zones = raw.compactMap { ZoneRect(dict: $0) }
        guard !zones.isEmpty, zones.count == raw.count else {
            return .badRequest("every zone needs x,y,w,h within 0..1, with w and h above 0")
        }
        store.update {
            $0.zoneSets[name] = zones
            if let screen = (body["screen"] as? NSNumber)?.intValue {
                $0.assignZoneSet(name, forKeys: ScreenIdentity.keys(forIndex: screen))
            }
        }
        didChangeZones?()
        return .ok(["ok": true, "saved": name, "zones": zones.count])
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
        guard let name = trimmedName(body["name"]) else {
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
    /// "the middle zone" is whatever the user sees as 2 in a three-zone set.
    func placeInZoneRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let app = trimmedName(body["app"]),
              let number = (body["zone"] as? NSNumber)?.intValue else {
            return .badRequest("body must be {\"app\", \"zone\": 1-based index, \"title\"?, \"screen\"?}")
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
        guard zones.indices.contains(number - 1) else {
            return .badRequest("screen \(screen) has zones 1...\(zones.count)")
        }
        let error = windows.place(app: app, titleContains: title, screen: screen,
                                  frac: zones[number - 1].frac, gap: CGFloat(store.config.zoneGap))
        if let error { return .failed(error) }
        return .ok(["ok": true, "app": app, "screen": screen, "zone": number, "zones": zones.count])
    }
}
