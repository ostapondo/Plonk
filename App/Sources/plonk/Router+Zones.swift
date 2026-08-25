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

    /// A rule for an app: the zone its windows open into, and optionally the
    /// display. The display arrives as an index and is stored as a UUID, so a
    /// rule written for the second monitor still means that monitor after the
    /// screens are renumbered.
    func setAppRuleRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let app = Self.trimmedName(body["app"]),
              let zone = (body["zone"] as? NSNumber)?.intValue else {
            return .badRequest("body must be {\"app\", \"zone\": 1-based index, \"screen\"?}")
        }
        guard zone >= 1 else {
            return .badRequest("zone must be at least 1")
        }
        var screenUUID: String?
        var screenIndex: Int?
        if let screen = (body["screen"] as? NSNumber)?.intValue {
            guard let uuid = ScreenIdentity.uuid(forIndex: screen) else {
                return .notFound("no screen \(screen)")
            }
            // A rule for a zone the named screen does not have would sit in
            // the list and never fire; better refused now, with the count.
            if case .failure(let refusal) = numberedZones(onScreen: screen, holding: zone) {
                return refusal.response
            }
            screenUUID = uuid
            screenIndex = screen
        } else if body["screen"] != nil, !(body["screen"] is NSNull) {
            return .badRequest("screen must be a monitor index")
        }
        let rule = AppRule(app: app, zone: zone, screenUUID: screenUUID)
        store.update { $0.appRules = AppRules.upsert(rule, in: $0.appRules) }
        // What was kept, not what was asked: the store trims and bounds.
        guard let stored = store.config.appRules.first(where: { AppRules.same($0.app, app) }) else {
            return .badRequest("app must not be blank")
        }
        return .ok(["ok": true, "rule": stored.asDict(screenIndex: screenIndex),
                    "rules": store.config.appRules.count])
    }

    /// Why a zone number cannot be used on a screen, as the answer to send.
    struct ZoneRefusal: Error {
        let response: HTTPResponse
    }

    /// The zones a screen has, when it has that many; else why not, the same
    /// answer whether a window is being placed or a rule written.
    func numberedZones(onScreen screen: Int, holding number: Int) -> Result<[ZoneRect], ZoneRefusal> {
        let zones = store.config.zones(forKeys: ScreenIdentity.keys(forIndex: screen))
        guard !zones.isEmpty else {
            return .failure(ZoneRefusal(response: .badRequest(
                "screen \(screen) uses edge snapping, so it has no numbered zones")))
        }
        guard zones.indices.contains(number - 1) else {
            return .failure(ZoneRefusal(response: .badRequest("screen \(screen) has zones 1...\(zones.count)")))
        }
        return .success(zones)
    }

    func deleteAppRuleRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let app = Self.trimmedName(body["app"]) else {
            return .badRequest("body must include app")
        }
        guard store.config.appRules.contains(where: { AppRules.same($0.app, app) }) else {
            return .notFound("no rule for \"\(app)\"")
        }
        store.update { $0.appRules = AppRules.remove(app: app, from: $0.appRules) }
        return .ok(["ok": true, "deleted": app])
    }

    /// Zones are addressed by the number the drag overlay draws on them, so
    /// "the middle zone" is whatever the user sees as 2 in a three-zone set.
    func placeInZoneRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let app = Self.trimmedName(body["app"]),
              let number = (body["zone"] as? NSNumber)?.intValue else {
            return .badRequest("body must be {\"app\", \"zone\": 1-based index, \"title\"?, \"screen\"?}")
        }
        let title = body["title"] as? String
        guard let screen = (body["screen"] as? NSNumber)?.intValue
                ?? windows.screenIndex(ofApp: app, titleContains: title) else {
            return .notFound("app \"\(app)\" is not running")
        }
        let zones: [ZoneRect]
        switch numberedZones(onScreen: screen, holding: number) {
        case .success(let set): zones = set
        case .failure(let refusal): return refusal.response
        }
        let error = windows.place(app: app, titleContains: title, screen: screen,
                                  frac: zones[number - 1].frac,
                                  gap: CGFloat(store.config.zoneGap(forKeys: ScreenIdentity.keys(forIndex: screen))))
        if let error { return .failed(error) }
        return .ok(["ok": true, "app": app, "screen": screen, "zone": number, "zones": zones.count])
    }
}
