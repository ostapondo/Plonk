import AppKit
import ApplicationServices

// Drag snapping. While a window is dragged:
// - if the screen under the cursor has an assigned zone set, all its zones are
//   shown and the hovered zone is highlighted; dropping snaps the window into
//   the full zone rect. The configured modifier gates activation, and holding
//   it inverts the mode (zones-on-drag <-> zones-on-modifier), so a free move
//   is always one keypress away.
// - holding Command as well spans: the zone the drag first hovered and the one
//   under the cursor now are covered by a single rect, so two columns become
//   one wide drop without editing the set.
// - otherwise, edge snapping: cursor near a screen edge shows a single zone
//   (edge middles = halves, top = maximize, edge ends = quarters).

final class DragSnapManager {
    /// Spanning is fixed rather than configurable: the activation modifier is
    /// already the user's to pick, and Command is the one that cannot collide
    /// with any of its three choices.
    static let spanFlag: NSEvent.ModifierFlags = .command

    private let windows: WindowManager
    private var monitors: [Any] = []
    var overlays: [Int: ZoneOverlay] = [:]
    var currentZone: (screenIndex: Int, frac: FracRect)?
    private var previewGeneration = 0
    /// One end of a span: the zone hovered when Command last went down.
    var spanAnchor: (screenIndex: Int, zoneIndex: Int)?

    private enum State {
        case idle
        case watching(win: AXUIElement, startFrame: CGRect)
        case active(win: AXUIElement, startFrame: CGRect)
        /// The drag belongs to an excluded app, so it is left alone until it ends.
        case ignored
    }
    private var state: State = .idle

    var enabled = true
    var requireModifier = true
    var modifierFlag: NSEvent.ModifierFlags = .shift
    var zonesForScreen: ((Int) -> [ZoneRect])?
    /// Looks and spacing, read fresh on every drag so a settings change shows
    /// up without restarting anything.
    var appearance: (() -> ZoneAppearance)?
    /// Draw every screen's zones during a drag, not just the one under the
    /// cursor. Costs an overlay per display.
    var showOnAllMonitors = false
    /// How near the shared edge of two zones the cursor has to come, in points,
    /// before the drop covers both. Zero switches it off.
    var edgeSpanPoints: Double = 0
    /// Apps the user told Plonk to keep its hands off.
    var isExcluded: ((NSRunningApplication) -> Bool)?
    /// Reports a finished snap, so the frame the window had can be given back.
    var onSnap: ((_ window: AXUIElement, _ before: CGRect, _ frac: FracRect, _ screenIndex: Int) -> Void)?

    init(windows: WindowManager) {
        self.windows = windows
    }

    /// Take the settings as they now stand. Called after every config change,
    /// so nothing here may cost more than a few assignments.
    func apply(_ config: Config) {
        enabled = config.dragSnapEnabled
        requireModifier = config.zonesRequireShift
        modifierFlag = config.zonesModifierFlag
        showOnAllMonitors = config.zonesOnAllMonitors
        edgeSpanPoints = config.zoneEdgeSpanPoints
    }

    func start() {
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged, handler: { [weak self] event in
            self?.handleDrag(event)
        }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] _ in
            self?.handleMouseUp()
        }) { monitors.append(m) }
    }

    /// Show one zone set on one screen until hidden (the picker's eye toggle).
    func showPreview(zones: [ZoneRect], screenIndex: Int) {
        previewGeneration += 1
        let screens = NSScreen.screens
        guard screens.indices.contains(screenIndex), !zones.isEmpty else { return }
        hideAll()
        overlay(for: screenIndex).show(zones: zones, highlighted: [],
                                       visible: screens[screenIndex].visibleFrame, appearance: look)
    }

    func hidePreviews() {
        previewGeneration += 1
        hideAll()
    }

    /// Flash all assigned zones on every screen (bound to ⌃⌥Z).
    func previewZones(duration: TimeInterval = 1.5) {
        previewGeneration += 1
        let generation = previewGeneration
        var shownAny = false
        for (index, screen) in NSScreen.screens.enumerated() {
            let zones = zonesForScreen?(index) ?? []
            guard !zones.isEmpty else { continue }
            shownAny = true
            overlay(for: index).show(zones: zones, highlighted: [], visible: screen.visibleFrame,
                                     appearance: look)
        }
        guard shownAny else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.previewGeneration == generation else { return }
            if case .idle = self.state { self.hideAll() }
        }
    }

    /// Drops overlays for displays that went away, so their windows are not
    /// left stranded at a frame that no longer exists.
    func screensChanged() {
        hidePreviews()
        let count = NSScreen.screens.count
        overlays = overlays.filter { $0.key < count }
    }

    // MARK: - Event handling

    private func handleDrag(_ event: NSEvent) {
        guard enabled, windows.isTrusted else { return }
        switch state {
        case .ignored:
            return
        case .idle:
            guard let app = NSWorkspace.shared.frontmostApplication else { return }
            guard isExcluded?(app) != true else {
                state = .ignored
                return
            }
            guard let win = windows.focusedWindow(of: app),
                  let frame = windows.frame(ofWindow: win) else { return }
            state = .watching(win: win, startFrame: frame)
        case .watching(let win, let startFrame):
            guard let f = windows.frame(ofWindow: win) else { state = .idle; return }
            let moved = abs(f.minX - startFrame.minX) > 4 || abs(f.minY - startFrame.minY) > 4
            let resized = abs(f.width - startFrame.width) > 2 || abs(f.height - startFrame.height) > 2
            if moved && !resized {
                state = .active(win: win, startFrame: startFrame)
                updateZone(event)
            }
        case .active:
            updateZone(event)
        }
    }

    private func handleMouseUp() {
        defer {
            state = .idle
            currentZone = nil
            spanAnchor = nil
            hideAll()
        }
        guard case .active(let win, let startFrame) = state, let zone = currentZone else { return }
        drop(win, startFrame: startFrame, into: zone)
    }

    private func drop(_ win: AXUIElement, startFrame: CGRect, into zone: (screenIndex: Int, frac: FracRect)) {
        windows.apply(frac: zone.frac, toWindow: win, screenIndex: zone.screenIndex, gap: look.gap)
        onSnap?(win, startFrame, zone.frac, zone.screenIndex)
    }

    var look: ZoneAppearance { appearance?() ?? ZoneAppearance() }

    // MARK: - Drags Plonk is driving itself

    /// Grab-and-move moves a window without the system ever raising a drag on
    /// it, so it hands the drag over here instead. Zones behave exactly as they
    /// do for a title-bar drag, which is the point: one set of rules.
    func beginExternalDrag(window: AXUIElement, startFrame: CGRect) {
        // "Drag to snap" is off means off, however the drag was started.
        guard enabled else { return }
        state = .active(win: window, startFrame: startFrame)
        spanAnchor = nil
    }

    func updateExternalDrag() {
        guard case .active = state else { return }
        updateZone(NSEvent.modifierFlags)
    }

    /// Drops into the highlighted zone if there is one, and reports whether it
    /// did — a caller that was moving the window freely needs to know whether
    /// its own frame or the zone won.
    @discardableResult
    func endExternalDrag() -> Bool {
        defer {
            state = .idle
            currentZone = nil
            spanAnchor = nil
            hideAll()
        }
        guard case .active(let win, let startFrame) = state, let zone = currentZone else { return false }
        drop(win, startFrame: startFrame, into: zone)
        return true
    }

    // MARK: - Overlays

    func overlay(for screenIndex: Int) -> ZoneOverlay {
        if let existing = overlays[screenIndex] { return existing }
        let created = ZoneOverlay()
        overlays[screenIndex] = created
        return created
    }

    func hideAll(except screenIndex: Int? = nil) {
        for (index, overlay) in overlays where index != screenIndex {
            overlay.hide()
        }
    }
}
