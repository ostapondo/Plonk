import CoreGraphics
import Foundation

// The one place in Plonk that fakes input, and it does so because there is no
// other way. Slack and Teams read the seconds since the last HID event
// (`powerMonitor.getSystemIdleTime` and what sits under it); the power
// assertion AwakeManager holds stops the Mac sleeping without touching that
// counter, so keeping the Mac up alone still leaves you Away. Only an event
// resets it.
//
// A consequence worth knowing rather than discovering: resetting the idle timer
// also postpones idle sleep and the screen saver. Being available implies being
// awake, not the other way round, which is why this is a level of one session
// rather than a feature beside it.

final class IdleNudge {
    private var timer: Timer?

    /// How often the idle timer is reset. Teams gives up after about five
    /// minutes and Slack after ten, so two minutes clears both with room for a
    /// missed tick.
    private static let seconds: TimeInterval = 120

    /// Shift, chosen because it changes nothing on its own: it types no
    /// character, moves no cursor and cannot disturb a drag the way a synthetic
    /// mouse move would.
    private static let shiftKey: CGKeyCode = 56

    var isRunning: Bool { timer != nil }

    func start() {
        guard timer == nil else { return }
        post()
        timer = Timer.common(every: Self.seconds) { [weak self] in self?.post() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Reset the idle counter. Posted to the HID tap rather than the session
    /// tap: the session tap inserts the event above the HID layer, where it
    /// reaches applications but does not necessarily count as user activity.
    private func post() {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source,
                                 virtualKey: Self.shiftKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source,
                               virtualKey: Self.shiftKey, keyDown: false)
        else { return }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
