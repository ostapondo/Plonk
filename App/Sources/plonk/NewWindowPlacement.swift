import CoreGraphics
import Foundation

// Where a window that just opened goes: a rule for its app, the habit its app
// has formed, or the first zone nobody is in, in that order. Pure, with the
// desk handed in as closures, so the order and every fall-through is tested
// without a window in sight.

struct NewWindowPlacement {
    struct Habit {
        let frac: FracRect
        let screenUUID: String?
        let zoneIndex: Int?
    }

    struct Answer: Equatable {
        let frac: FracRect
        let screen: Int
        /// Which numbered zone, when the answer is one, so it is remembered
        /// by number and follows the set when the set changes.
        let zoneIndex: Int?
    }

    let rules: [AppRule]
    let placeNewWindows: Bool
    let autoFillZones: Bool
    /// Where a display is now, or nil while it is not attached.
    let screenIndex: (String) -> Int?
    let zones: (Int) -> [ZoneRect]
    /// The first zone on a screen nothing is in, or nil when every one is
    /// taken. Asked only when the other two have nothing to say, since it
    /// costs a look at the window server.
    let firstEmpty: (Int) -> Int?

    /// Whether the app is one any of the three could place, before a single
    /// window is asked about: the cheap answer that keeps a rule for Slack
    /// from costing every other app's windows a round trip.
    func wants(name: String, bundleID: String?, hasHabit: Bool) -> Bool {
        autoFillZones || (placeNewWindows && hasHabit)
            || AppRules.match(name: name, bundleID: bundleID, rules: rules) != nil
    }

    /// The answer for a window of `name` that opened on screen `opened`, or
    /// nil to leave it where the app put it.
    func decide(name: String, bundleID: String?, habit: Habit?, openedOn opened: Int) -> Answer? {
        if let rule = AppRules.match(name: name, bundleID: bundleID, rules: rules) {
            // The named display when it is attached, else the one the window
            // opened on: a rule must not strand a window on a monitor that is
            // in a drawer. A zone the set on that screen does not have leaves
            // the rule unfollowed, and the habit and the empty zone get their
            // turn.
            let screen = rule.screenUUID.flatMap(screenIndex) ?? opened
            if let frac = zoneFrac(rule.zone - 1, on: screen) {
                return Answer(frac: frac, screen: screen, zoneIndex: rule.zone - 1)
            }
        }
        // A habit is followed by zone number where it was a zone, so it
        // survives the set being edited, and by fraction otherwise. One on a
        // display that is not attached does not apply.
        if placeNewWindows, let habit, let uuid = habit.screenUUID, let screen = screenIndex(uuid) {
            if let zone = habit.zoneIndex, let frac = zoneFrac(zone, on: screen) {
                return Answer(frac: frac, screen: screen, zoneIndex: zone)
            }
            return Answer(frac: habit.frac, screen: screen, zoneIndex: nil)
        }
        if autoFillZones, let zone = firstEmpty(opened), let frac = zoneFrac(zone, on: opened) {
            return Answer(frac: frac, screen: opened, zoneIndex: zone)
        }
        return nil
    }

    private func zoneFrac(_ index: Int, on screen: Int) -> FracRect? {
        let set = zones(screen)
        return set.indices.contains(index) ? set[index].frac : nil
    }
}
