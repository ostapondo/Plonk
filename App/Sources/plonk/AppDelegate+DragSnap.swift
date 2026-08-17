import AppKit

// Dragging a window: the zone overlay it drops into, and the modifier that
// lets a drag start anywhere inside the window rather than on its title bar.
//
// One file because they are one gesture. A grab is a drag as far as zones are
// concerned, so grab-and-move drives the same overlay.

extension AppDelegate {
    /// Wiring only: what drag snapping asks the app for, and what it reports
    /// back. The settings it reads are applied separately, because they change
    /// while the app is running and this does not.
    func setupDragSnap() {
        dragSnap = DragSnapManager(windows: windows)
        dragSnap.zonesForScreen = { [weak self] index in
            guard let self else { return [] }
            return store.config.zones(forKeys: ScreenIdentity.keys(forIndex: index))
        }
        dragSnap.appearance = { [weak self] in self?.zoneAppearance ?? ZoneAppearance() }
        dragSnap.isExcluded = { [weak self] app in self?.isExcluded(app) ?? false }
        dragSnap.onSnap = { [weak self] window, before, frac, screenIndex in
            guard let self else { return }
            snapMemory.record(window, wasAt: before, placedAt: frac,
                              screenUUID: ScreenIdentity.uuid(forIndex: screenIndex),
                              zoneIndex: zoneIndex(of: frac, onScreen: screenIndex),
                              appKey: windows.app(ofWindow: window)?.bundleIdentifier)
        }
        applyDragSnapSettings()
        dragSnap.start()
    }

    func applyDragSnapSettings() {
        dragSnap.enabled = store.config.dragSnapEnabled
        dragSnap.requireModifier = store.config.zonesRequireShift
        dragSnap.modifierFlag = Self.modifierFlag(store.config.zonesModifier)
        dragSnap.showOnAllMonitors = store.config.zonesOnAllMonitors
        dragSnap.edgeSpanPoints = store.config.zoneEdgeSpanPoints
    }

    var zoneAppearance: ZoneAppearance {
        ZoneAppearance(gap: CGFloat(store.config.zoneGap),
                       opacity: CGFloat(store.config.zoneOpacity),
                       // Falls back to the app's accent, which itself falls back
                       // to the system one, so the overlay is part of the theme.
                       color: ZoneAppearance.color(fromHex: store.config.zoneColorHex)
                           ?? ZoneAppearance.color(fromHex: store.config.appearance.accentHex),
                       showNumbers: store.config.zoneNumbersVisible)
    }

    func setupGrabMove() {
        grabMove = GrabMove(windows: windows)
        grabMove.isExcluded = { [weak self] app in self?.isExcluded(app) ?? false }
        // A grab is a drag as far as zones are concerned, so it goes through
        // the same overlay and the same drop rules.
        grabMove.onGrabBegan = { [weak self] window, frame in
            self?.dragSnap.beginExternalDrag(window: window, startFrame: frame)
        }
        grabMove.onGrabMoved = { [weak self] in self?.dragSnap.updateExternalDrag() }
        grabMove.onGrabResized = { [weak self] window, startFrame in
            guard let self, let placed = windows.fraction(ofWindow: window) else { return }
            snapMemory.record(window, wasAt: startFrame, placedAt: placed.frac,
                              screenUUID: ScreenIdentity.uuid(forIndex: placed.screenIndex),
                              appKey: windows.app(ofWindow: window)?.bundleIdentifier)
            router?.changes.bump("windows")
        }
        grabMove.onGrabEnded = { [weak self] window, startFrame in
            guard let self else { return }
            // A grab that landed in a zone is recorded by the zone drop. One
            // that did not is still a move Plonk made, so it is remembered
            // too — otherwise the shortcut that puts a window back would have
            // nothing to put back after a free drag.
            if !dragSnap.endExternalDrag(), let placed = windows.fraction(ofWindow: window) {
                snapMemory.record(window, wasAt: startFrame, placedAt: placed.frac,
                                  screenUUID: ScreenIdentity.uuid(forIndex: placed.screenIndex))
            }
            router?.changes.bump("windows")
        }
        applyGrabMoveSettings()
    }

    /// An event tap that can swallow clicks has no business existing while the
    /// feature is off, so the tap follows the setting rather than the launch.
    func applyGrabMoveSettings() {
        grabMove.enabled = store.config.grabMoveEnabled
        grabMove.modifierFlag = Self.modifierFlag(store.config.grabMoveModifier)
        grabMove.allowResize = store.config.grabMoveResize
        grabMove.showGeometry = store.config.grabMoveShowGeometry
        if store.config.grabMoveEnabled {
            grabMove.start()
        } else {
            grabMove.stop()
        }
    }

    /// Which numbered zone a dropped fraction corresponds to, so editing the
    /// set later can move the window with its number. Nil for a span or an
    /// edge snap, which match no single zone.
    func zoneIndex(of frac: FracRect, onScreen index: Int) -> Int? {
        let zones = store.config.zones(forKeys: ScreenIdentity.keys(forIndex: index))
        return zones.firstIndex {
            abs($0.x - frac.x) < 0.001 && abs($0.y - frac.y) < 0.001
                && abs($0.w - frac.w) < 0.001 && abs($0.h - frac.h) < 0.001
        }
    }

    func setupNewWindows() {
        newWindows = NewWindowWatcher(windows: windows)
        newWindows.enabled = store.config.placeNewWindows
        newWindows.isExcluded = { [weak self] app in self?.isExcluded(app) ?? false }
        newWindows.zoneGap = { [weak self] in CGFloat(self?.store.config.zoneGap ?? 0) }
        newWindows.placement = { [weak self] app in
            guard let self, let key = app.bundleIdentifier,
                  let habit = snapMemory.habit(ofApp: key) else { return nil }
            // The display is named by UUID, so a habit formed on a monitor that
            // has since been unplugged simply does not apply.
            guard let uuid = habit.screenUUID, let index = ScreenIdentity.index(forUUID: uuid) else { return nil }
            // A numbered zone is followed by number, so the habit survives the
            // set being edited; anything else falls back to the raw fraction.
            let zones = store.config.zones(forKeys: ScreenIdentity.keys(forIndex: index))
            if let zone = habit.zoneIndex, zones.indices.contains(zone) {
                return (zones[zone].frac, index)
            }
            return (habit.frac, index)
        }
        newWindows.onPlaced = { [weak self] app, window, before, frac, screenIndex in
            guard let self else { return }
            snapMemory.record(window, wasAt: before, placedAt: frac,
                              screenUUID: ScreenIdentity.uuid(forIndex: screenIndex),
                              zoneIndex: zoneIndex(of: frac, onScreen: screenIndex),
                              appKey: app.bundleIdentifier)
            router?.changes.bump("windows")
        }
        newWindows.start()
    }

    static func modifierFlag(_ name: String) -> NSEvent.ModifierFlags {
        switch name {
        case "option": return .option
        case "control": return .control
        case "command": return .command
        default: return .shift
        }
    }
}
