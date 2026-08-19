import AppKit

// The sidebar is a panel set into the window by `Ink.inset` on every side, and
// macOS puts the traffic lights where the panel's corner now is. They move in
// so they sit inside the panel, the way the design draws them.

enum TrafficLights {
    /// AppKit lays the buttons out again on every resize and when the window
    /// enters or leaves full screen, so the move is re-applied then, and it is
    /// stated against where the buttons started so applying it twice lands in
    /// the same place.
    static func inset(in window: NSWindow) {
        // Where AppKit put them, taken once. The move is stated against that
        // rather than against wherever the button is now, so applying it a
        // second time lands in the same place instead of a step further.
        let kinds: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let home = kinds.compactMap { kind in window.standardWindowButton(kind).map { ($0, $0.frame.origin) } }
        guard let first = home.first?.1.x, let last = home.last else { return }
        let span = last.1.x + last.0.frame.width - first
        let nudge = { [weak window] in
            guard let window else { return }
            // Where the close button's left edge goes, from the window's edge.
            // In the wide sidebar it lines up with the search field, ten points
            // into the panel. In the rail the three sit centred, because a row
            // of lights that nearly spans the panel reads as crooked the moment
            // it is off by a little.
            let rail = window.frame.width < MainWindowView.railBelow
            let left = Ink.inset + (rail ? (MainWindowView.rail - span) / 2 : 10)
            for (button, origin) in home {
                button.setFrameOrigin(NSPoint(x: origin.x - first + left,
                                              y: origin.y - Ink.inset - 6))
            }
        }
        nudge()
        for name in [NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification,
                     NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification,
                     NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { _ in
                nudge()
            }
        }
    }
}
