import AppKit
import ApplicationServices

// All coordinates exposed to the API are in AX space: origin at the top-left
// of the primary screen, y grows downward. Fractional frames are relative to
// a screen's visible area (excludes menu bar and Dock), origin top-left.

final class WindowManager {

    /// Fires on the main queue after any window actually moves, whoever asked —
    /// hotkeys, drag snapping, workspace launches or the HTTP routes.
    var onDidPlace: (() -> Void)?

    // MARK: - Accessibility
    //
    // WindowAccess holds every call into the Accessibility API; what is here is
    // the part of it this app hands to the rest of itself, plus the one place
    // that announces a move.

    var isTrusted: Bool { WindowAccess.isTrusted }
    func promptForTrust() { WindowAccess.promptForTrust() }
    func frame(ofWindow win: AXUIElement) -> CGRect? { WindowAccess.frame(of: win) }
    func window(at point: CGPoint) -> AXUIElement? { WindowAccess.window(at: point) }
    func app(ofWindow win: AXUIElement) -> NSRunningApplication? { WindowAccess.app(ofWindow: win) }
    func focusedWindow(of app: NSRunningApplication) -> AXUIElement? {
        WindowAccess.focusedWindow(of: app)
    }

    /// Placement during a live drag. Announces nothing: the change bus would
    /// otherwise fire on every mouse event, and the drop announces once.
    func setFrame(_ rect: CGRect, ofWindow win: AXUIElement) {
        _ = WindowAccess.setFrame(rect, of: win)
    }

    /// Every other placement. Hotkeys, drag drops, workspace launches and the
    /// HTTP routes all reach here, so this is the one place that sees a window
    /// move and the only one that has to announce it. Launches run off the
    /// main queue, which is why the callback hops back onto it.
    @discardableResult
    private func place(_ win: AXUIElement, _ rect: CGRect) -> Bool {
        guard WindowAccess.setFrame(rect, of: win) else { return false }
        if let onDidPlace { DispatchQueue.main.async(execute: onDidPlace) }
        return true
    }

    // MARK: - Coordinate conversion

    private func toAX(_ r: NSRect, primaryMaxY: CGFloat) -> CGRect {
        CGRect(x: r.origin.x, y: primaryMaxY - r.maxY, width: r.width, height: r.height)
    }

    struct ScreenInfo {
        let index: Int
        let frame: CGRect      // AX space
        let visible: CGRect    // AX space
    }

    func screens() -> [ScreenInfo] {
        let all = NSScreen.screens
        let primaryMaxY = all.first?.frame.maxY ?? 0
        return all.enumerated().map { i, s in
            ScreenInfo(index: i,
                       frame: toAX(s.frame, primaryMaxY: primaryMaxY),
                       visible: toAX(s.visibleFrame, primaryMaxY: primaryMaxY))
        }
    }

    private func screenIndex(containing axRect: CGRect, in all: [ScreenInfo]) -> Int {
        let center = CGPoint(x: axRect.midX, y: axRect.midY)
        return all.first { $0.frame.contains(center) }?.index ?? 0
    }

    private func axRect(for frac: FracRect, screenIndex: Int, in all: [ScreenInfo],
                        gap: CGFloat = 0) -> CGRect {
        guard !all.isEmpty else { return .zero }
        let v = all[min(max(screenIndex, 0), all.count - 1)].visible
        return ZoneGeometry.frame(for: frac, in: v, gap: gap)
    }

    // MARK: - App matching

    private func runningApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
    }

    private func findApp(named query: String) -> NSRunningApplication? {
        let q = query.lowercased()
        let apps = runningApps()
        if let exact = apps.first(where: { ($0.localizedName ?? "").lowercased() == q }) { return exact }
        if let sub = apps.first(where: { ($0.localizedName ?? "").lowercased().contains(q) }) { return sub }
        return apps.first(where: { ($0.bundleIdentifier ?? "").lowercased().contains(q) })
    }

    // MARK: - Public API

    func listWindows() -> [[String: Any]] {
        var result: [[String: Any]] = []
        let allScreens = screens()
        let ownPID = ProcessInfo.processInfo.processIdentifier
        for app in runningApps() where app.processIdentifier != ownPID {
            let name = app.localizedName ?? "?"
            for (windowIndex, win) in WindowAccess.windows(of: app.processIdentifier).enumerated() {
                guard let f = frame(ofWindow: win) else { continue }
                let minimized = WindowAccess.isMinimized(win)
                let index = screenIndex(containing: f, in: allScreens)
                var entry: [String: Any] = [
                    "app": name,
                    "pid": app.processIdentifier,
                    "title": WindowAccess.title(of: win),
                    "minimized": minimized,
                    "screen": index,
                    "window_index": windowIndex,
                    // Doubles, not CGFloat: CGFloat is its own struct, and a
                    // [String: CGFloat] does not cast to [String: Double].
                    "frame": ["x": Double(f.origin.x), "y": Double(f.origin.y),
                              "w": Double(f.width), "h": Double(f.height)],
                ]
                if let bundleID = app.bundleIdentifier { entry["bundle_id"] = bundleID }
                if let path = app.bundleURL?.path { entry["bundle_path"] = path }
                let v = allScreens[index].visible
                if !minimized, v.width > 0, v.height > 0 {
                    entry["fraction"] = [
                        "x": Double(round((f.minX - v.minX) / v.width * 100) / 100),
                        "y": Double(round((f.minY - v.minY) / v.height * 100) / 100),
                        "w": Double(round(f.width / v.width * 100) / 100),
                        "h": Double(round(f.height / v.height * 100) / 100),
                    ]
                }
                result.append(entry)
            }
        }
        return result
    }

    /// Place one window by app name. Returns an error string, or nil on success.
    func place(app appName: String, titleContains: String?, screen screenIdx: Int?, frac: FracRect,
               gap: CGFloat = 0) -> String? {
        place(app: appName, bundleID: nil, titleContains: titleContains, windowIndex: nil,
              screen: screenIdx, frac: frac, gap: gap)
    }

    /// The workspace form: addresses a specific window of an app and can leave
    /// it minimized afterwards.
    ///
    /// `gap` defaults to none because most callers hand over a fraction that is
    /// already exactly where the window goes: a workspace saved a frame that had
    /// the gap in it, and a frame given as fractions is taken literally. Only a
    /// caller naming a *zone* passes one, so an agent dropping a window into
    /// zone 3 leaves the same space around it as ⌃⌥3 does.
    func place(app appName: String, bundleID: String?, titleContains: String?, windowIndex: Int?,
               screen screenIdx: Int?, frac: FracRect,
               minimize: Bool = false, activate: Bool = true, gap: CGFloat = 0) -> String? {
        guard isTrusted else { return "accessibility permission not granted" }
        let all = screens()
        if let screenIdx, !all.indices.contains(screenIdx) {
            return all.isEmpty
                ? "no screens available"
                : "no screen \(screenIdx); screens are 0...\(all.count - 1)"
        }
        guard let app = findApp(bundleID: bundleID, named: appName) else {
            return "app \"\(appName)\" is not running"
        }
        guard let win = pickWindow(of: app, titleContains: titleContains, windowIndex: windowIndex) else {
            return "no matching window for \"\(appName)\""
        }
        if WindowAccess.isMinimized(win) {
            WindowAccess.setMinimized(false, of: win)
        }
        let index = screenIdx ?? screenIndex(containing: frame(ofWindow: win) ?? .zero, in: all)
        guard place(win, axRect(for: frac, screenIndex: index, in: all, gap: gap)) else {
            return "window of \"\(appName)\" refused to move or resize"
        }
        if activate { app.activate() }
        // Minimizing right after a resize confuses some apps, so it goes last.
        if minimize {
            WindowAccess.setMinimized(true, of: win)
        }
        return nil
    }

    /// The window an app name points at: the one at `windowIndex` if it has
    /// one, else the first not minimized. A title is a hint, because windows
    /// get renamed as their content changes, and no match is worse than the
    /// wrong window.
    private func pickWindow(of app: NSRunningApplication, titleContains: String?,
                            windowIndex: Int?) -> AXUIElement? {
        var wins = WindowAccess.windows(of: app.processIdentifier)
        if let t = titleContains?.lowercased(), !t.isEmpty {
            let matching = wins.filter { WindowAccess.title(of: $0).lowercased().contains(t) }
            if !matching.isEmpty { wins = matching }
        }
        if let windowIndex, wins.indices.contains(windowIndex) { return wins[windowIndex] }
        return wins.first(where: { !WindowAccess.isMinimized($0) }) ?? wins.first
    }

    /// Running app for a workspace item. The bundle ID is exact; the name is
    /// the fallback for items saved before one was recorded.
    func findApp(bundleID: String?, named name: String) -> NSRunningApplication? {
        if let bundleID, !bundleID.isEmpty,
           let match = runningApps().first(where: { $0.bundleIdentifier == bundleID }) {
            return match
        }
        return findApp(named: name)
    }

    /// Zero also covers an app that is not running.
    func windowCount(bundleID: String?, named name: String) -> Int {
        guard let app = findApp(bundleID: bundleID, named: name) else { return 0 }
        return WindowAccess.windows(of: app.processIdentifier).count
    }

    /// Which screen an app's window currently sits on, or nil when not running.
    func screenIndex(ofApp appName: String, titleContains: String?) -> Int? {
        guard let app = findApp(named: appName),
              let win = pickWindow(of: app, titleContains: titleContains, windowIndex: nil),
              let f = frame(ofWindow: win) else { return nil }
        return screenIndex(containing: f, in: screens())
    }

    /// Place a specific window (used by drag snapping). `gap` is the empty
    /// space left around the zone, in points, so a snapped window can breathe.
    func apply(frac: FracRect, toWindow win: AXUIElement, screenIndex: Int, gap: CGFloat = 0) {
        place(win, axRect(for: frac, screenIndex: screenIndex, in: screens(), gap: gap))
    }

    /// Which screen a window sits on, by the screen its centre falls in.
    func screenIndex(ofWindow win: AXUIElement) -> Int {
        screenIndex(containing: frame(ofWindow: win) ?? .zero, in: screens())
    }

    /// Where a window sits, as a fraction of its screen's visible area. Nil
    /// when there is no frame or no screen to measure against.
    ///
    /// Clamped inside the screen: a window hanging over an edge still has to
    /// come back as a fraction the placement path would accept.
    func fraction(ofWindow win: AXUIElement) -> (frac: FracRect, screenIndex: Int)? {
        let all = screens()
        guard let f = frame(ofWindow: win), !all.isEmpty else { return nil }
        let index = screenIndex(containing: f, in: all)
        let v = all[index].visible
        guard v.width > 0, v.height > 0 else { return nil }
        let x = min(max(Double((f.minX - v.minX) / v.width), 0), 0.99)
        let y = min(max(Double((f.minY - v.minY) / v.height), 0), 0.99)
        let w = min(max(Double(f.width / v.width), 0.01), 1 - x)
        let h = min(max(Double(f.height / v.height), 0.01), 1 - y)
        return (FracRect(x, y, w, h), index)
    }

    /// Put a window back at a frame it held earlier, nudged onto whichever
    /// screen still exists. Used by unsnapping, where the size matters more
    /// than the exact spot.
    @discardableResult
    func restore(frame rect: CGRect, toWindow win: AXUIElement) -> Bool {
        let all = screens()
        guard !all.isEmpty else { return false }
        let index = screenIndex(containing: rect, in: all)
        return place(win, WindowNavigator.clamped(rect, into: all[index].visible))
    }

    /// Every window Plonk can address, with its frame and title, excluding
    /// Plonk's own. Several AX round trips per window, so callers should not
    /// do this per event.
    ///
    /// The order is AX's, which is front-to-back and therefore changes the
    /// moment anything is raised. Anything that walks this list more than once
    /// has to impose its own order first.
    func allWindows() -> [(app: NSRunningApplication, window: AXUIElement, frame: CGRect, title: String)] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var result: [(NSRunningApplication, AXUIElement, CGRect, String)] = []
        for app in runningApps() where app.processIdentifier != ownPID {
            for win in WindowAccess.windows(of: app.processIdentifier) where !WindowAccess.isMinimized(win) {
                guard let f = frame(ofWindow: win) else { continue }
                result.append((app, win, f, WindowAccess.title(of: win)))
            }
        }
        return result
    }

    /// Brings a window forward and gives it focus. Raising alone leaves the
    /// keyboard with whatever was in front, so the app is activated too.
    func focus(_ win: AXUIElement, of app: NSRunningApplication) {
        WindowAccess.raise(win)
        app.activate()
    }
}
