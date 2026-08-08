import ApplicationServices
import Foundation

// What a window looked like before Plonk moved it, and where it was put.
//
// Two things need this. Unsnapping restores the frame the window had before
// its first snap, so a window that was dragged into a zone can be given back.
// A display change re-applies the fraction each remembered window was placed
// at, keyed by display UUID, so unplugging a monitor and plugging it back in
// does not leave windows piled on the wrong screen.
//
// Entries are keyed by the AX element, which stays equal for the life of a
// window (AXUIElement supports CFEqual), and are capped: a long session opens
// and closes far more windows than anyone will ever unsnap.

/// AXUIElement is a CFType, so it needs the CF identity functions rather than
/// the synthesized ones.
struct WindowKey: Hashable {
    let element: AXUIElement

    static func == (lhs: WindowKey, rhs: WindowKey) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(CFHash(element))
    }
}

/// Main-queue only: every caller is a hotkey, a drag or a screen notification.
final class SnapMemory {
    struct Entry {
        /// Frame the window had before Plonk first moved it, in AX space.
        var original: CGRect
        /// Where it was last put, as a fraction of a display's visible area.
        var frac: FracRect
        /// The display it was put on, so a re-plug can find it again.
        var screenUUID: String?
        var stamp: Int
    }

    private static let capacity = 64

    private var entries: [WindowKey: Entry] = [:]
    private var counter = 0

    /// Records a placement. The original frame is kept from the first call for
    /// a window: snapping left and then right should still restore what the
    /// window looked like before any of it.
    func record(_ window: AXUIElement, wasAt original: CGRect, placedAt frac: FracRect, screenUUID: String?) {
        counter += 1
        let key = WindowKey(element: window)
        if var existing = entries[key] {
            existing.frac = frac
            existing.screenUUID = screenUUID
            existing.stamp = counter
            entries[key] = existing
        } else {
            entries[key] = Entry(original: original, frac: frac, screenUUID: screenUUID, stamp: counter)
        }
        prune()
    }

    /// The frame to restore, removing the entry: unsnapping twice in a row
    /// should not keep dragging the window back to the same place.
    func takeOriginal(of window: AXUIElement) -> CGRect? {
        entries.removeValue(forKey: WindowKey(element: window))?.original
    }

    func forget(_ window: AXUIElement) {
        entries.removeValue(forKey: WindowKey(element: window))
    }

    /// Every remembered placement, newest last.
    var placements: [(window: AXUIElement, frac: FracRect, screenUUID: String?)] {
        entries
            .sorted { $0.value.stamp < $1.value.stamp }
            .map { ($0.key.element, $0.value.frac, $0.value.screenUUID) }
    }

    var count: Int { entries.count }

    /// Drops the least recently touched entries once the table is over
    /// capacity. Windows that have closed are indistinguishable from live ones
    /// without asking their app, which is IPC we do not owe this.
    private func prune() {
        guard entries.count > Self.capacity else { return }
        let doomed = entries
            .sorted { $0.value.stamp < $1.value.stamp }
            .prefix(entries.count - Self.capacity)
            .map(\.key)
        for key in doomed { entries.removeValue(forKey: key) }
    }
}
