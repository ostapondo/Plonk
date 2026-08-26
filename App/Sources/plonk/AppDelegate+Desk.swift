import AppKit

// The desk, noted as windows move so a display coming back finds every window
// where it was. DeskWatcher does the work; this is how the app drives it.

extension AppDelegate {
    func setupDesk() {
        desk.isExcluded = exclusionCheck
        desk.apply(store.config)
    }

    /// After a display has come or gone and the apps have caught up: the
    /// desk as it was last seen under these displays, then the zone
    /// placements for whatever the desk had no note of, a window opened on
    /// a Space it never saw say. The desk is the fresher record, since every
    /// placement is noted the moment it is made, so a window it knows is not
    /// moved twice. Its moves are announced once, all together; the zone
    /// placements announce themselves.
    func restoreAfterScreenChange(to displays: Set<String>) {
        desk.restore(for: displays) { [weak self] handled in
            guard let self else { return }
            commands.restorePlacements(except: handled)
            if !handled.isEmpty { router?.changes.bump("windows") }
            desk.scheduleSnapshot()
        }
    }
}
