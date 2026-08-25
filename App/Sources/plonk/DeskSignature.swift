import AppKit

// What the window server says the desk looks like, as one number. One call,
// no app asked anything, so it can be taken every tick; a walk over AX only
// follows when the number has changed.

enum DeskSignature {
    /// Every window on screen, by id, owner and bounds. Layer 0 only, the
    /// way the capture picker reads the list, so a tooltip or a menu coming
    /// and going is not a changed desk; sorted by id, so a window merely
    /// raised is not one either. Two desks that hash alike are the same
    /// desk for all the noting cares.
    static func current(excluding ownPID: pid_t = ProcessInfo.processInfo.processIdentifier) -> Int {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        var seen: [(id: CGWindowID, pid: pid_t, bounds: CGRect)] = []
        for entry in info {
            guard let id = entry[kCGWindowNumber as String] as? CGWindowID,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  (entry[kCGWindowLayer as String] as? Int) == 0,
                  let boundsDict = entry[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { continue }
            seen.append((id, pid, bounds))
        }
        var hasher = Hasher()
        for window in seen.sorted(by: { $0.id < $1.id }) {
            hasher.combine(window.id)
            hasher.combine(window.pid)
            hasher.combine(window.bounds.origin.x)
            hasher.combine(window.bounds.origin.y)
            hasher.combine(window.bounds.width)
            hasher.combine(window.bounds.height)
        }
        return hasher.finalize()
    }
}
