import AppKit

// One reader of the window server's list, for the two things that ask it:
// which windows can be photographed, and which are on screen right now. The
// list is what the window server draws, so it knows what Accessibility does
// not: whether a window is on the current Space and not hidden. Asking it is
// one call, with no round trip into any app.

enum WindowServer {
    struct Window {
        let id: CGWindowID
        let pid: pid_t
        /// AX space: the window server puts the origin at the top-left of the
        /// primary display too, so nothing is flipped.
        let bounds: CGRect
        let onScreen: Bool
        let ownerName: String
        let title: String
    }

    /// Smaller than this on a side and it is a shadow, a drop target or a
    /// scratch surface, never something a person would call a window.
    static let minimumSide: CGFloat = 40

    /// Windows front to back, defaulting to ordinary layer-0 windows large
    /// enough to place in a zone and excluding Plonk. `onScreenOnly` asks for
    /// what is on the current Space and not hidden, which is cheaper than the
    /// whole list and is what "empty" means when a zone is being filled.
    static func windows(onScreenOnly: Bool,
                        excluding own: pid_t = ProcessInfo.processInfo.processIdentifier,
                        levels: Set<Int> = [NSWindow.Level.normal.rawValue],
                        minimumSide: CGFloat = WindowServer.minimumSide) -> [Window] {
        let options: CGWindowListOption = onScreenOnly ? [.optionOnScreenOnly, .excludeDesktopElements] : .optionAll
        let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return info.compactMap { entry in
            guard let id = entry[kCGWindowNumber as String] as? CGWindowID,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid != own,
                  let level = entry[kCGWindowLayer as String] as? Int, levels.contains(level),
                  (entry[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let boundsDict = entry[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.width >= minimumSide, bounds.height >= minimumSide else { return nil }
            return Window(id: id, pid: pid, bounds: bounds,
                          // The key is only present when it is true.
                          onScreen: entry[kCGWindowIsOnscreen as String] as? Bool ?? false,
                          ownerName: entry[kCGWindowOwnerName as String] as? String ?? "?",
                          title: entry[kCGWindowName as String] as? String ?? "")
        }
    }

    static func screenshotWindowBounds() -> [CGRect] {
        let levels = [NSWindow.Level.normal.rawValue, NSWindow.Level.floating.rawValue,
                      NSWindow.Level.modalPanel.rawValue, Int(CGWindowLevelForKey(.utilityWindow))]
        return windows(onScreenOnly: true, levels: Set(levels), minimumSide: 1).map(\.bounds)
    }

    /// The same window seen through the window server and through
    /// Accessibility: the window server rounds to whole points, so within
    /// one is the same frame.
    static func sameFrame(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 1 && abs(a.minY - b.minY) < 1
            && abs(a.width - b.width) < 1 && abs(a.height - b.height) < 1
    }
}
