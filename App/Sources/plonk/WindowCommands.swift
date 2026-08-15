import AppKit
import ApplicationServices

// The moves that act on whatever is in front, rather than on a window an agent
// named: drop it into a numbered zone, put it back where it was, step focus to
// the neighbour, or cycle between the windows sharing a zone.
//
// All of them respect the exclusion list, because all of them fire from a key
// the user may hit while a game or a remote desktop has focus.

final class WindowCommands {
    private let windows: WindowManager
    private let memory: SnapMemory

    var zonesForScreen: ((Int) -> [ZoneRect])?
    var isExcluded: ((NSRunningApplication) -> Bool)?
    var announce: ((String) -> Void)?
    /// Empty space left around a snapped window, in points.
    var zoneGap: (() -> CGFloat)?

    init(windows: WindowManager, memory: SnapMemory) {
        self.windows = windows
        self.memory = memory
    }

    /// The frontmost window, unless its app is excluded or there is none.
    private func focused() -> (app: NSRunningApplication, window: AXUIElement, frame: CGRect)? {
        guard windows.isTrusted,
              let app = NSWorkspace.shared.frontmostApplication,
              isExcluded?(app) != true,
              let window = windows.focusedWindow(of: app),
              let frame = windows.frame(ofWindow: window) else { return nil }
        return (app, window, frame)
    }

    func apply(_ preset: Preset) {
        guard let target = focused() else { return }
        let screen = windows.screenIndex(ofWindow: target.window)
        remember(target, frac: preset.frac, screen: screen)
        // Presets are halves and quarters of the screen, not zones, so the
        // zone gap does not apply to them.
        windows.apply(frac: preset.frac, toWindow: target.window, screenIndex: screen)
    }

    /// Snap to the zone the drag overlay draws that number on.
    func snap(toZone number: Int) {
        guard let target = focused() else { return }
        let screen = windows.screenIndex(ofWindow: target.window)
        let zones = zonesForScreen?(screen) ?? []
        guard !zones.isEmpty else {
            announce?("That screen uses edge snapping, so it has no numbered zones")
            return
        }
        guard zones.indices.contains(number - 1) else {
            announce?("That screen has zones 1–\(zones.count)")
            return
        }
        let frac = zones[number - 1].frac
        remember(target, frac: frac, screen: screen, zoneIndex: number - 1)
        windows.apply(frac: frac, toWindow: target.window, screenIndex: screen, gap: zoneGap?() ?? 0)
    }

    /// Give a window back the frame it had before Plonk first moved it.
    func unsnap() {
        guard let target = focused() else { return }
        guard let original = memory.takeOriginal(of: target.window) else {
            announce?("Plonk has not moved this window")
            return
        }
        windows.restore(frame: original, toWindow: target.window)
    }

    /// Raise the next window whose centre shares a zone with this one.
    func cycleZone(backwards: Bool) {
        guard let target = focused() else { return }
        let screenIndex = windows.screenIndex(ofWindow: target.window)
        let zones = zonesForScreen?(screenIndex) ?? []
        let screens = windows.screens()
        guard screens.indices.contains(screenIndex) else { return }
        let visible = screens[screenIndex].visible

        let bounds = screens[screenIndex].frame
        // Sorted, because AX hands windows back front-to-back: cycling raises
        // one, which reorders the list, and an unsorted "next" would bounce
        // between the top two forever without ever reaching a third.
        let all = windows.allWindows()
            .filter { bounds.contains($0.frame.center) }
            .sorted(by: Self.stableOrder)
        guard let current = all.firstIndex(where: { CFEqual($0.window, target.window) }) else { return }
        // Overlapping zones resolve the same way a drop does — smallest wins —
        // and a screen with no zones counts as one, which turns this into
        // "next window over here". Still the useful move.
        let zone = zones
            .filter { Self.rect(of: $0, in: visible).contains(target.frame.center) }
            .min { $0.w * $0.h < $1.w * $1.h }
            .map { Self.rect(of: $0, in: visible) } ?? visible

        guard let next = WindowNavigator.nextInZone(after: current, candidates: all.map(\.frame),
                                                    zone: zone, backwards: backwards) else {
            announce?("Nothing else is in this zone")
            return
        }
        windows.focus(all[next].window, of: all[next].app)
    }

    /// Step focus to the nearest window in a direction, across screens.
    func moveFocus(_ direction: WindowNavigator.Direction) {
        guard let target = focused() else { return }
        let all = windows.allWindows().filter { !CFEqual($0.window, target.window) }
        guard let index = WindowNavigator.target(from: target.frame, candidates: all.map(\.frame),
                                                 direction: direction) else { return }
        windows.focus(all[index].window, of: all[index].app)
    }

    /// After a display is plugged in or unplugged, put every window Plonk
    /// placed back at the fraction it was placed at, on the display it was
    /// placed on. Windows whose display is gone are left alone: guessing a new
    /// screen for them would scatter a layout rather than preserve it.
    func restorePlacements() {
        let gap = zoneGap?() ?? 0
        for placement in memory.placements {
            guard let uuid = placement.screenUUID, let index = ScreenIdentity.index(forUUID: uuid),
                  mayTouch(placement.window) else { continue }
            windows.apply(frac: placement.frac, toWindow: placement.window, screenIndex: index, gap: gap)
        }
    }

    /// After a screen's zone set is edited or swapped, move every window that
    /// went into a numbered zone to wherever that number is now. A window at a
    /// remembered fraction rather than a zone is left where it is: it was never
    /// in the set that changed.
    func relayout(screenIndex: Int) {
        let zones = zonesForScreen?(screenIndex) ?? []
        guard !zones.isEmpty, let uuid = ScreenIdentity.uuid(forIndex: screenIndex) else { return }
        let gap = zoneGap?() ?? 0
        for placement in memory.placements {
            guard placement.screenUUID == uuid, let zone = placement.zoneIndex,
                  zones.indices.contains(zone), mayTouch(placement.window) else { continue }
            windows.apply(frac: zones[zone].frac, toWindow: placement.window,
                          screenIndex: screenIndex, gap: gap)
            memory.record(placement.window,
                          wasAt: windows.frame(ofWindow: placement.window) ?? .zero,
                          placedAt: zones[zone].frac, screenUUID: uuid, zoneIndex: zone)
        }
    }

    /// Apply a whole zone set to the screen under the cursor, by its position
    /// in the list the settings show. PowerToys binds a hotkey per layout in
    /// its editor; here the list is the binding, so a set can be swapped
    /// without opening anything.
    func applyZoneSet(number: Int, named names: [String], assign: (String, Int) -> Void) {
        guard names.indices.contains(number - 1) else {
            announce?(names.isEmpty ? "No zone sets to switch to" : "There are \(names.count) zone sets")
            return
        }
        assign(names[number - 1], ScreenIdentity.indexUnderCursor)
        announce?(names[number - 1])
    }

    /// The exclusion list applies to every move Plonk makes on its own, not
    /// just the ones a key started: a display change must not resize a game.
    private func mayTouch(_ window: AXUIElement) -> Bool {
        guard let app = windows.app(ofWindow: window) else { return false }
        return isExcluded?(app) != true
    }

    private func remember(_ target: (app: NSRunningApplication, window: AXUIElement, frame: CGRect),
                          frac: FracRect, screen: Int, zoneIndex: Int? = nil) {
        memory.record(target.window, wasAt: target.frame, placedAt: frac,
                      screenUUID: ScreenIdentity.uuid(forIndex: screen), zoneIndex: zoneIndex,
                      appKey: target.app.bundleIdentifier)
    }

    /// An order nothing Plonk does can change: the app, then the title, then
    /// where the window sits. Raising a window touches none of those, which is
    /// what keeps a cycle a ring rather than a coin flip.
    private static func stableOrder(_ a: (app: NSRunningApplication, window: AXUIElement, frame: CGRect, title: String),
                                    _ b: (app: NSRunningApplication, window: AXUIElement, frame: CGRect, title: String)) -> Bool {
        if a.app.processIdentifier != b.app.processIdentifier {
            return a.app.processIdentifier < b.app.processIdentifier
        }
        if a.title != b.title { return a.title < b.title }
        if a.frame.minX != b.frame.minX { return a.frame.minX < b.frame.minX }
        return a.frame.minY < b.frame.minY
    }

    /// Zone rects are fractions of a screen's visible area; window frames are
    /// absolute AX points. These two turn one into the other.
    private static func rect(of zone: ZoneRect, in visible: CGRect) -> CGRect {
        CGRect(x: visible.minX + zone.x * visible.width,
               y: visible.minY + zone.y * visible.height,
               width: zone.w * visible.width,
               height: zone.h * visible.height)
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
