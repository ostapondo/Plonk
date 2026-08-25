import AppKit

// GET /state, and the /layout route that places a batch of windows.
//
// Everything an agent can learn in one request. Keys are machine-readable and
// stay English, whatever language the app is drawn in; see AGENTS.md, "Text".

extension Router {
    func state() -> [String: Any] {
        let zoneSets = BuiltinZoneSets.all.merging(store.config.zoneSets) { _, custom in custom }
            .mapValues { $0.map(\.asDict) }

        let screens = windows.screens()
        // Assignments are stored per display UUID; agents work in screen indices.
        var assignments: [String: String] = [:]
        for screen in screens {
            if let name = store.config.zoneAssignment(forKeys: ScreenIdentity.keys(forIndex: screen.index)) {
                assignments[String(screen.index)] = name
            }
        }

        var state: [String: Any] = [
            "rev": changes.rev,
            "awake": awake.isOn,
            "awake_details": awakeState(),
            "accessibility_granted": windows.isTrusted,
            // Off by the user's choice; a route under one of these answers 409.
            "disabled_features": store.config.disabledFeatures,
            "excluded_apps": store.config.excludedApps,
            "text_languages": store.config.textLanguages,
            "saved_layouts": store.config.workspaces.keys.sorted(),
            "workspaces": store.config.workspaces.mapValues { workspace in
                [
                    "move_existing": workspace.moveExisting,
                    "apps": workspace.apps,
                    "items": workspace.items.map(\.asDict),
                ] as [String: Any]
            },
            "zone_sets": zoneSets,
            "zone_gap": store.config.zoneGap,
            "zone_set_gaps": store.config.zoneSetGaps,
            "screen_zone_sets": assignments,
            "screens": screens.map { s in
                [
                    "index": s.index,
                    "frame": ["x": s.frame.minX, "y": s.frame.minY, "w": s.frame.width, "h": s.frame.height],
                    "visible": ["x": s.visible.minX, "y": s.visible.minY, "w": s.visible.width, "h": s.visible.height],
                ]
            },
            "windows": windows.listWindows(),
            "agents": agents.describe(selected: store.config.selectedAgent),
            "agent_adapters": store.config.agentAdapters.map(\.name),
            "agent_exclusive": store.config.agentExclusive,
        ]
        if let update = updateState?() { state["update"] = update }
        if let selected = store.config.selectedAgent { state["selected_agent"] = selected }
        return state
    }

    /// Places a batch. Each item answers for itself, so one bad frame does not
    /// cost the caller the windows that were fine.
    func layoutRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let items = body["items"] as? [[String: Any]], !items.isEmpty else {
            return .badRequest("body must be {\"items\": [{app, title?, screen?, frame:{x,y,w,h}}]}")
        }
        let results = items.map { item -> [String: Any] in
            guard let spec = LayoutItemSpec(dict: item) else {
                return ["ok": false,
                        "error": "item needs app and frame {x,y,w,h} within 0..1, with w and h above 0"]
            }
            return place(spec)
        }
        return .ok(["results": results, "accessibility_granted": windows.isTrusted])
    }

    private func place(_ spec: LayoutItemSpec) -> [String: Any] {
        let error = windows.place(
            app: spec.app,
            titleContains: spec.title,
            screen: spec.screen,
            frac: FracRect(spec.x, spec.y, spec.w, spec.h)
        )
        return error.map { ["ok": false, "app": spec.app, "error": $0] } ?? ["ok": true, "app": spec.app]
    }
}
