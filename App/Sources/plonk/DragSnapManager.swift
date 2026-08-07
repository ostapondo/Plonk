import AppKit
import ApplicationServices

// Drag snapping. While a window is dragged:
// - if the screen under the cursor has an assigned zone set, all its zones are
//   shown and the hovered zone is highlighted; dropping snaps the window into
//   the full zone rect. The configured modifier gates activation, and holding
//   it inverts the mode (zones-on-drag <-> zones-on-modifier), so a free move
//   is always one keypress away.
// - otherwise, edge snapping: cursor near a screen edge shows a single zone
//   (edge middles = halves, top = maximize, edge ends = quarters).

final class DragSnapManager {
    private let windows: WindowManager
    private var monitors: [Any] = []
    private var overlays: [Int: ZoneOverlay] = [:]
    private var currentZone: (screenIndex: Int, frac: FracRect)?
    private var previewGeneration = 0

    private enum State {
        case idle
        case watching(win: AXUIElement, startFrame: CGRect)
        case active(win: AXUIElement)
    }
    private var state: State = .idle

    var enabled = true
    var requireModifier = true
    var modifierFlag: NSEvent.ModifierFlags = .shift
    var zonesForScreen: ((Int) -> [ZoneRect])?

    init(windows: WindowManager) {
        self.windows = windows
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
        overlay(for: screenIndex).show(zones: zones, hovered: nil, visible: screens[screenIndex].visibleFrame)
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
            overlay(for: index).show(zones: zones, hovered: nil, visible: screen.visibleFrame)
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
        case .idle:
            guard let app = NSWorkspace.shared.frontmostApplication,
                  let win = windows.focusedWindow(of: app),
                  let frame = windows.frame(ofWindow: win) else { return }
            state = .watching(win: win, startFrame: frame)
        case .watching(let win, let startFrame):
            guard let f = windows.frame(ofWindow: win) else { state = .idle; return }
            let moved = abs(f.minX - startFrame.minX) > 4 || abs(f.minY - startFrame.minY) > 4
            let resized = abs(f.width - startFrame.width) > 2 || abs(f.height - startFrame.height) > 2
            if moved && !resized {
                state = .active(win: win)
                updateZone(modifierHeld: event.modifierFlags.contains(modifierFlag))
            }
        case .active:
            updateZone(modifierHeld: event.modifierFlags.contains(modifierFlag))
        }
    }

    private func handleMouseUp() {
        defer {
            state = .idle
            currentZone = nil
            hideAll()
        }
        guard case .active(let win) = state, let zone = currentZone else { return }
        windows.apply(frac: zone.frac, toWindow: win, screenIndex: zone.screenIndex)
    }

    private func updateZone(modifierHeld: Bool) {
        let p = NSEvent.mouseLocation
        guard let index = NSScreen.screens.firstIndex(where: { $0.frame.insetBy(dx: -1, dy: -1).contains(p) }) else {
            currentZone = nil
            hideAll()
            return
        }
        let screen = NSScreen.screens[index]
        let zones = zonesForScreen?(index) ?? []

        if !zones.isEmpty {
            // The modifier inverts the activation mode, so the other behavior stays reachable.
            guard modifierHeld == requireModifier else {
                currentZone = nil
                hideAll()
                return
            }
            let v = screen.visibleFrame
            let hovered = zoneIndex(at: p, in: zones, visible: v)
            overlay(for: index).show(zones: zones, hovered: hovered, visible: v)
            hideAll(except: index)
            currentZone = hovered.map { (index, zones[$0].frac) }
        } else if let frac = edgeZone(at: p, on: screen) {
            overlay(for: index).show(zones: [ZoneRect(frac.x, frac.y, frac.w, frac.h)], hovered: 0,
                                     visible: screen.visibleFrame)
            hideAll(except: index)
            currentZone = (index, frac)
        } else {
            currentZone = nil
            hideAll()
        }
    }

    /// Smallest zone under the cursor, so overlapping sets stay usable.
    private func zoneIndex(at p: NSPoint, in zones: [ZoneRect], visible v: NSRect) -> Int? {
        let fx = (p.x - v.minX) / v.width
        let fyTop = (v.maxY - p.y) / v.height
        var hovered: Int?
        var smallest = Double.infinity
        for (i, z) in zones.enumerated()
        where fx >= z.x && fx <= z.x + z.w && fyTop >= z.y && fyTop <= z.y + z.h {
            let area = z.w * z.h
            if area < smallest { smallest = area; hovered = i }
        }
        return hovered
    }

    // MARK: - Edge fallback geometry

    private func edgeZone(at p: NSPoint, on screen: NSScreen) -> FracRect? {
        let f = screen.frame
        let margin: CGFloat = 24
        let fx = (p.x - f.minX) / f.width
        let fyTop = (f.maxY - p.y) / f.height

        if p.x - f.minX < margin {
            if fyTop < 0.25 { return Preset.topLeft.frac }
            if fyTop > 0.75 { return Preset.bottomLeft.frac }
            return Preset.leftHalf.frac
        }
        if f.maxX - p.x < margin {
            if fyTop < 0.25 { return Preset.topRight.frac }
            if fyTop > 0.75 { return Preset.bottomRight.frac }
            return Preset.rightHalf.frac
        }
        if f.maxY - p.y < margin {
            if fx < 0.25 { return Preset.topLeft.frac }
            if fx > 0.75 { return Preset.topRight.frac }
            return Preset.maximize.frac
        }
        if p.y - f.minY < margin {
            if fx < 0.25 { return Preset.bottomLeft.frac }
            if fx > 0.75 { return Preset.bottomRight.frac }
            return Preset.bottomHalf.frac
        }
        return nil
    }

    // MARK: - Overlays

    private func overlay(for screenIndex: Int) -> ZoneOverlay {
        if let existing = overlays[screenIndex] { return existing }
        let created = ZoneOverlay()
        overlays[screenIndex] = created
        return created
    }

    private func hideAll(except screenIndex: Int? = nil) {
        for (index, overlay) in overlays where index != screenIndex {
            overlay.hide()
        }
    }
}
