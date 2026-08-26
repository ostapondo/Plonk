import ApplicationServices
import Foundation

// Where every window sat, per set of displays.
//
// macOS scrambles windows when a monitor goes away and does not put them back
// when it returns. SnapMemory covers the windows Plonk placed; this covers the
// rest: the whole desk, noted while nothing is changing and keyed by which
// displays were attached, so the moment that same set is attached again every
// window can go back where it was. DeskWatcher does the noting; a walk of
// the whole desk now and then, and each window Plonk places the moment it
// is placed.
//
// In memory only. An AXUIElement does not survive a relaunch, and neither
// does the scramble: a fresh launch finds the desk however it is.

/// Main-queue only: written from a walk's completion and a placement, read
/// from the screen-change handler, all of which run there.
final class DeskMemory {
    struct Entry {
        let window: AXUIElement
        /// Where it sat, as a fraction of its display's visible area.
        let frac: FracRect
        let screenUUID: String
    }

    /// A set of displays is its own key: a laptop alone, a laptop at the desk,
    /// a laptop at the dock. There are as many desks as there are places the
    /// Mac goes, which is few.
    private var desks: [Set<String>: [Entry]] = [:]

    /// Replaces what is known about that set of displays. Nothing is kept
    /// for no displays at all, which is what a Mac with its lid shut reports.
    func record(_ entries: [Entry], for displays: Set<String>) {
        guard !displays.isEmpty else { return }
        desks[displays] = entries
    }

    /// Where the windows sat the last time this set of displays was
    /// attached; empty for a set never seen.
    func entries(for displays: Set<String>) -> [Entry] {
        desks[displays] ?? []
    }

    /// One window's place, known at once rather than at the next walk.
    func note(_ entry: Entry, for displays: Set<String>) {
        guard !displays.isEmpty else { return }
        let key = WindowKey(element: entry.window)
        var entries = desks[displays, default: []].filter { WindowKey(element: $0.window) != key }
        entries.append(entry)
        desks[displays] = entries
    }

    func clear() {
        desks = [:]
    }

    /// A fresh walk over what was known. A window seen now takes its new
    /// place; one not seen keeps its old place while `alive` says it is
    /// still there, since a walk only sees the Space in front and a window
    /// parked on another one has not gone anywhere; one that is gone goes.
    static func merged(_ known: [Entry], with fresh: [Entry], alive: (AXUIElement) -> Bool) -> [Entry] {
        let seen = Set(fresh.map { WindowKey(element: $0.window) })
        let kept = known.filter { !seen.contains(WindowKey(element: $0.window)) && alive($0.window) }
        return fresh + kept
    }
}
