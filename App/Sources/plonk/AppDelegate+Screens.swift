import AppKit

// Displays coming and going. A Dock resize and a monitor being unplugged both
// arrive as the same notification, which is why the display UUIDs are kept.

extension AppDelegate {
    @objc func screensChanged() {
        dragSnap.screensChanged()
        model.previewedZoneSet = nil
        refreshZoneModel()

        // This notification also fires for a resolution change, a display
        // waking, and the Dock being resized or auto-hidden. Only a display
        // actually arriving or leaving should move anybody's windows.
        let displays = Self.attachedDisplays()
        defer { knownDisplays = displays }
        guard store.config.restoreZonesOnScreenChange, displays != knownDisplays else { return }

        // macOS sends this before the apps behind those windows have caught up,
        // and several times while a display wakes. Settling first, then placing
        // once, is the difference between windows landing and windows fighting.
        screenSettleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.commands.restorePlacements() }
        screenSettleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    /// Grab-and-move, the pointer tools and the new-window watcher all need
    /// Accessibility to arm, and on a first run it has just been asked for and
    /// not yet given. Rather than making each of them dead until the next
    /// launch, this waits for the grant and starts them then. Drag snapping
    /// does not need it because it re-checks on every event.
    func watchForAccessibility() {
        guard !windows.isTrusted else { return }
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            guard windows.isTrusted else { return }
            timer.invalidate()
            applyGrabMoveSettings()
            applyMouseSettings()
            newWindows.start()
            refreshPermissions()
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    static func attachedDisplays() -> Set<String> {
        Set(NSScreen.screens.indices.compactMap { ScreenIdentity.uuid(forIndex: $0) })
    }
}
