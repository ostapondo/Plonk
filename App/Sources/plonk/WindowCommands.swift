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
        remember(target, frac: frac, screen: screen)
        windows.apply(frac: frac, toWindow: target.window, screenIndex: screen)
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
        let all = windows.allWindows().filter { bounds.contains($0.frame.center) }
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
        for placement in memory.placements {
            guard let uuid = placement.screenUUID, let index = ScreenIdentity.index(forUUID: uuid) else { continue }
            windows.apply(frac: placement.frac, toWindow: placement.window, screenIndex: index)
        }
    }

    private func remember(_ target: (app: NSRunningApplication, window: AXUIElement, frame: CGRect),
                          frac: FracRect, screen: Int) {
        memory.record(target.window, wasAt: target.frame, placedAt: frac,
                      screenUUID: ScreenIdentity.uuid(forIndex: screen))
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
