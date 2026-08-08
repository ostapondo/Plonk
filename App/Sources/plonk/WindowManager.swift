import AppKit
import ApplicationServices

// All coordinates exposed to the API are in AX space: origin at the top-left
// of the primary screen, y grows downward. Fractional frames are relative to
// a screen's visible area (excludes menu bar and Dock), origin top-left.

struct FracRect {
    let x, y, w, h: Double
    init(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }

    /// Parses a `{x,y,w,h}` frame from an API body. Must stay inside the screen
    /// it is a fraction of; the epsilon absorbs rounding from `get_state`.
    static func parse(_ value: Any?) -> FracRect? {
        guard let frame = value as? [String: Any],
              let x = (frame["x"] as? NSNumber)?.doubleValue,
              let y = (frame["y"] as? NSNumber)?.doubleValue,
              let w = (frame["w"] as? NSNumber)?.doubleValue,
              let h = (frame["h"] as? NSNumber)?.doubleValue,
              x.isFinite, y.isFinite, w.isFinite, h.isFinite,
              w > 0, h > 0, x >= 0, y >= 0,
              x + w <= 1.0001, y + h <= 1.0001 else { return nil }
        return FracRect(x, y, w, h)
    }
}

enum Preset: String, CaseIterable {
    case leftHalf = "left-half"
    case rightHalf = "right-half"
    case topHalf = "top-half"
    case bottomHalf = "bottom-half"
    case topLeft = "top-left"
    case topRight = "top-right"
    case bottomLeft = "bottom-left"
    case bottomRight = "bottom-right"
    case maximize = "maximize"
    case center = "center"

    var frac: FracRect {
        switch self {
        case .leftHalf: return FracRect(0, 0, 0.5, 1)
        case .rightHalf: return FracRect(0.5, 0, 0.5, 1)
        case .topHalf: return FracRect(0, 0, 1, 0.5)
        case .bottomHalf: return FracRect(0, 0.5, 1, 0.5)
        case .topLeft: return FracRect(0, 0, 0.5, 0.5)
        case .topRight: return FracRect(0.5, 0, 0.5, 0.5)
        case .bottomLeft: return FracRect(0, 0.5, 0.5, 0.5)
        case .bottomRight: return FracRect(0.5, 0.5, 0.5, 0.5)
        case .maximize: return FracRect(0, 0, 1, 1)
        case .center: return FracRect(0.2, 0.15, 0.6, 0.7)
        }
    }

    var title: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        case .maximize: return "Maximize"
        case .center: return "Center"
        }
    }
}

final class WindowManager {

    /// AX calls are synchronous IPC into the target app. Drag snapping makes
    /// one per mouse event, so a hung app must not take the cursor with it.
    private static let axTimeout: Float = 0.25

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

    // MARK: - AX helpers

    var isTrusted: Bool { AXIsProcessTrusted() }

    /// Fires on the main queue after any window actually moves, whoever asked —
    /// hotkeys, drag snapping, workspace launches or the HTTP routes.
    var onDidPlace: (() -> Void)?

    func promptForTrust() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    private func appElement(_ pid: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, Self.axTimeout)
        return element
    }

    private func axWindows(of pid: pid_t) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement(pid), kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return [] }
        return windows.filter { (attr($0, kAXRoleAttribute) as? String) == kAXWindowRole }
    }

    private func attr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, name as CFString, &value) == .success else { return nil }
        return value
    }

    func frame(ofWindow win: AXUIElement) -> CGRect? {
        guard let posVal = attr(win, kAXPositionAttribute), let sizeVal = attr(win, kAXSizeAttribute) else { return nil }
        var pos = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posVal as! AXValue, .cgPoint, &pos),
              AXValueGetValue(sizeVal as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: pos, size: size)
    }

    func focusedWindow(of app: NSRunningApplication) -> AXUIElement? {
        let pid = app.processIdentifier
        if let focused = attr(appElement(pid), kAXFocusedWindowAttribute),
           CFGetTypeID(focused) == AXUIElementGetTypeID() {
            return (focused as! AXUIElement)
        }
        return axWindows(of: pid).first { !isMinimized($0) }
    }

    private func isMinimized(_ win: AXUIElement) -> Bool {
        (attr(win, kAXMinimizedAttribute) as? Bool) ?? false
    }

    private func title(of win: AXUIElement) -> String {
        (attr(win, kAXTitleAttribute) as? String) ?? ""
    }

    /// The window under a point in AX space, or nil over the desktop. Walks up
    /// from whatever element is there — a button, a text field — to the window
    /// containing it.
    func window(at point: CGPoint) -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, Self.axTimeout)
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &element) == .success,
              var current = element else { return nil }
        // Ten levels is deeper than any real view hierarchy needs; the bound is
        // there because a malformed AX tree can contain a cycle.
        for _ in 0..<10 {
            if (attr(current, kAXRoleAttribute) as? String) == kAXWindowRole { return current }
            guard let parent = attr(current, kAXParentAttribute),
                  CFGetTypeID(parent) == AXUIElementGetTypeID() else { return nil }
            current = (parent as! AXUIElement)
        }
        return nil
    }

    func app(ofWindow win: AXUIElement) -> NSRunningApplication? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(win, &pid) == .success else { return nil }
        return NSRunningApplication(processIdentifier: pid)
    }

    /// Placement during a live drag. Announces nothing: the change bus would
    /// otherwise fire on every mouse event, and the drop announces once.
    func setFrame(_ rect: CGRect, ofWindow win: AXUIElement) {
        setFrame(win, rect, announce: false)
    }

    @discardableResult
    private func setFrame(_ win: AXUIElement, _ rect: CGRect, announce: Bool = true) -> Bool {
        var pos = rect.origin
        var size = rect.size
        guard let posVal = AXValueCreate(.cgPoint, &pos),
              let sizeVal = AXValueCreate(.cgSize, &size) else { return false }
        // Position → size → position again: some apps clamp one against the other.
        let movedTo = AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, posVal)
        let resized = AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, sizeVal)
        AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, posVal)
        guard movedTo == .success && resized == .success else { return false }
        // Placement reaches here from hotkeys, drag snapping, workspace
        // launches and the HTTP routes alike, so this is the one place that
        // sees every window move. Launches run off the main queue.
        if announce, let onDidPlace {
            DispatchQueue.main.async(execute: onDidPlace)
        }
        return true
    }

    private func axRect(for frac: FracRect, screenIndex: Int, in all: [ScreenInfo]) -> CGRect {
        guard !all.isEmpty else { return .zero }
        let v = all[min(max(screenIndex, 0), all.count - 1)].visible
        return CGRect(
            x: v.minX + frac.x * v.width,
            y: v.minY + frac.y * v.height,
            width: frac.w * v.width,
            height: frac.h * v.height
        )
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
            for (windowIndex, win) in axWindows(of: app.processIdentifier).enumerated() {
                guard let f = frame(ofWindow: win) else { continue }
                let minimized = isMinimized(win)
                let index = screenIndex(containing: f, in: allScreens)
                var entry: [String: Any] = [
                    "app": name,
                    "pid": app.processIdentifier,
                    "title": title(of: win),
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
    func place(app appName: String, titleContains: String?, screen screenIdx: Int?, frac: FracRect) -> String? {
        place(app: appName, bundleID: nil, titleContains: titleContains, windowIndex: nil,
              screen: screenIdx, frac: frac)
    }

    /// The workspace form: addresses a specific window of an app and can leave
    /// it minimized afterwards.
    func place(app appName: String, bundleID: String?, titleContains: String?, windowIndex: Int?,
               screen screenIdx: Int?, frac: FracRect,
               minimize: Bool = false, activate: Bool = true) -> String? {
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
        var wins = axWindows(of: app.processIdentifier)
        if let t = titleContains?.lowercased(), !t.isEmpty {
            let matching = wins.filter { title(of: $0).lowercased().contains(t) }
            // A saved title is a hint: windows get renamed as their content
            // changes, and no match is worse than the wrong window.
            if !matching.isEmpty { wins = matching }
        }
        let win: AXUIElement?
        if let windowIndex, wins.indices.contains(windowIndex) {
            win = wins[windowIndex]
        } else {
            win = wins.first(where: { !isMinimized($0) }) ?? wins.first
        }
        guard let win else { return "no matching window for \"\(appName)\"" }
        if isMinimized(win) {
            AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        let index = screenIdx ?? screenIndex(containing: frame(ofWindow: win) ?? .zero, in: all)
        guard setFrame(win, axRect(for: frac, screenIndex: index, in: all)) else {
            return "window of \"\(appName)\" refused to move or resize"
        }
        if activate { app.activate() }
        // Minimizing right after a resize confuses some apps, so it goes last.
        if minimize {
            AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        }
        return nil
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
        return axWindows(of: app.processIdentifier).count
    }

    /// Which screen an app's window currently sits on, or nil when not running.
    func screenIndex(ofApp appName: String, titleContains: String?) -> Int? {
        guard let app = findApp(named: appName) else { return nil }
        var wins = axWindows(of: app.processIdentifier)
        if let t = titleContains?.lowercased(), !t.isEmpty {
            wins = wins.filter { title(of: $0).lowercased().contains(t) }
        }
        guard let win = wins.first(where: { !isMinimized($0) }) ?? wins.first,
              let f = frame(ofWindow: win) else { return nil }
        return screenIndex(containing: f, in: screens())
    }

    /// Place a specific window (used by drag snapping). `gap` is the empty
    /// space left around the zone, in points, so a snapped window can breathe.
    func apply(frac: FracRect, toWindow win: AXUIElement, screenIndex: Int, gap: CGFloat = 0) {
        let rect = axRect(for: frac, screenIndex: screenIndex, in: screens())
        setFrame(win, gap > 0 ? rect.insetBy(dx: gap, dy: gap) : rect)
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
        return setFrame(win, WindowNavigator.clamped(rect, into: all[index].visible))
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
            for win in axWindows(of: app.processIdentifier) where !isMinimized(win) {
                guard let f = frame(ofWindow: win) else { continue }
                result.append((app, win, f, title(of: win)))
            }
        }
        return result
    }

    /// Brings a window forward and gives it focus. Raising alone leaves the
    /// keyboard with whatever was in front, so the app is activated too.
    func focus(_ win: AXUIElement, of app: NSRunningApplication) {
        AXUIElementPerformAction(win, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(win, kAXMainAttribute as CFString, kCFBooleanTrue)
        app.activate()
    }
}
