import AppKit

// A window that just opened, and where it goes. The decision is
// NewWindowPlacement's; this is the desk it decides about, handed in.

extension AppDelegate {
    func setupNewWindows() {
        newWindows = NewWindowWatcher(windows: windows)
        newWindows.apply(store.config)
        newWindows.isExcluded = exclusionCheck
        newWindows.zoneGap = { [weak self] index in self?.zoneGapPoints(onScreen: index) ?? 0 }
        newWindows.wants = { [weak self] app in
            guard let self else { return false }
            return newWindowPlacement.wants(name: app.localizedName ?? "", bundleID: app.bundleIdentifier,
                                            hasHabit: app.bundleIdentifier.flatMap(snapMemory.habit(ofApp:)) != nil)
        }
        newWindows.placement = { [weak self] app, frame in self?.placement(for: app, frame: frame) }
        // Remembered so it can be put back, but not as the app's habit: a
        // habit is where the user put a window, and a placement Plonk made by
        // itself would otherwise become the reason for the next one.
        newWindows.onPlaced = { [weak self] window, before, answer in
            guard let self else { return }
            snapMemory.record(window, wasAt: before, placedAt: answer.frac,
                              screenUUID: ScreenIdentity.uuid(forIndex: answer.screen),
                              zoneIndex: answer.zoneIndex)
            router?.changes.bump("windows")
        }
        newWindows.start()
    }

    /// The decision, over the desk as it is now.
    var newWindowPlacement: NewWindowPlacement {
        let config = store.config
        return NewWindowPlacement(
            rules: config.appRules,
            placeNewWindows: config.placeNewWindows,
            autoFillZones: config.autoFillZones,
            screenIndex: ScreenIdentity.index(forUUID:),
            zones: { [weak self] index in self?.zones(onScreen: index) ?? [] },
            firstEmpty: { [weak self] index in self?.firstEmptyZone(onScreen: index) }
        )
    }

    /// Where a new window of `app` goes, or nil to leave it where the app
    /// put it. `frame` is where it is now, already read by the watcher.
    func placement(for app: NSRunningApplication, frame: CGRect) -> NewWindowPlacement.Answer? {
        let habit = app.bundleIdentifier.flatMap(snapMemory.habit(ofApp:)).map {
            NewWindowPlacement.Habit(frac: $0.frac, screenUUID: $0.screenUUID, zoneIndex: $0.zoneIndex)
        }
        // The window that just opened is on screen too and must not count as
        // taking a zone. It is the front-most of its app's windows at that
        // frame, since the window server lists front to back; a twin behind
        // it at the same frame is a real occupant and stays.
        placing = (app.processIdentifier, frame)
        defer { placing = nil }
        return newWindowPlacement.decide(name: app.localizedName ?? "", bundleID: app.bundleIdentifier,
                                         habit: habit, openedOn: windows.screenIndex(containing: frame))
    }

    /// The first zone on a screen with nothing visible in it. What the
    /// window server has on screen, so a hidden app or a window on another
    /// Space does not hold a zone nobody can see it in.
    private func firstEmptyZone(onScreen index: Int) -> Int? {
        let zones = zones(onScreen: index)
        let screens = windows.screens()
        guard !zones.isEmpty, screens.indices.contains(index) else { return nil }
        var onScreen = WindowServer.windows(onScreenOnly: true)
        if let placing, let own = onScreen.firstIndex(where: {
            $0.pid == placing.pid && WindowServer.sameFrame($0.bounds, placing.frame)
        }) {
            onScreen.remove(at: own)
        }
        let own = placing.map { CGPoint(x: $0.frame.midX, y: $0.frame.midY) }
        return ZoneGeometry.firstEmpty(zones, in: screens[index].visible, occupied: onScreen.map(\.bounds),
                                       preferring: own)
    }
}
