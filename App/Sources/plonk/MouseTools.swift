import AppKit

// Four small things for the cursor, all of them a transparent click-through
// window and an event tap that only ever reads.
//
// - Find it: a shortcut dims everything but a circle around the pointer, so a
//   cursor lost on a wide desk is found without waggling the mouse. PowerToys
//   offers a double-tap of Control as well; that cannot be told apart from a
//   Control chord without watching every keystroke the user types, which is
//   not a capability this app is going to take for a convenience.
// - Highlight clicks: a coloured ring on every press. This is for anyone
//   recording a demo — a click is invisible in a screen recording otherwise.
// - Crosshairs: full-width and full-height lines through the pointer, for
//   lining things up and for anyone who needs the cursor to be findable
//   all the time rather than on demand.
// - Jump: a hotkey warps the pointer to the middle of the next screen, which
//   beats shoving a mouse across three monitors.

final class MouseTools {
    private static let spotlightRadius: CGFloat = 110
    private static let clickRadius: CGFloat = 34

    private let overlay = MouseOverlay()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var spotlightToken = 0
    private var lastCrosshair: NSPoint?

    var highlightEnabled = false
    var crosshairsEnabled = false {
        didSet { if crosshairsEnabled != oldValue { refreshPersistent() } }
    }
    var tint: NSColor = .controlAccentColor

    /// Take the settings as they now stand. Called after every config change,
    /// so it stops only a tap that is actually running: `stop` also hides the
    /// overlay, and a find-the-cursor flash is on screen without any tap
    /// behind it. Tearing that down because some other page's setting moved is
    /// a spotlight that blinks out under the user's hand.
    func apply(_ config: Config) {
        tint = ZoneAppearance(config).tint
        highlightEnabled = config.highlightClicksEnabled
        crosshairsEnabled = config.crosshairsEnabled
        if config.highlightClicksEnabled || config.crosshairsEnabled {
            start()
        } else if tap != nil {
            stop()
        }
    }

    func start() {
        guard tap == nil else { return }
        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue)

        let context = Unmanaged.passUnretained(self).toOpaque()
        // A listen-only tap: these tools watch the pointer, they never take an
        // event away from anybody.
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                Unmanaged<MouseTools>.fromOpaque(context).takeUnretainedValue().handle(type, event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: context
        ) else {
            NSLog("Plonk: could not create the mouse-tools event tap")
            return
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = source
        CGEvent.tapEnable(tap: tap, enable: true)
        refreshPersistent()
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        runLoopSource = nil
        tap = nil
        overlay.hide()
    }

    /// What this has on screen, so a capture can get it out of the way.
    var visibleWindows: [NSWindow] { overlay.visibleWindows }

    /// Held while a capture is in flight. Ordering the overlay out is not
    /// enough on its own: the next mouse move would draw it straight back,
    /// into the photograph.
    private var suspended = false

    /// Stops drawing until `resume`, and takes down whatever is showing.
    func suspend() {
        suspended = true
        overlay.hide()
    }

    func resume() {
        suspended = false
        refreshPersistent()
    }

    // MARK: - Jump

    /// Warps the pointer to the middle of the next screen, wrapping round.
    /// Nothing to do on a single display, so it says so rather than blinking.
    @discardableResult
    func jumpToNextScreen() -> Bool {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return false }
        let mouse = NSEvent.mouseLocation
        let current = screens.firstIndex { $0.frame.contains(mouse) } ?? 0
        let next = screens[(current + 1) % screens.count]
        let centre = CGPoint(x: next.frame.midX, y: next.frame.midY)
        // CGWarpMouseCursorPosition works in CG space: origin top-left of the
        // primary display, y downward, which is the flip of NSScreen's.
        let primaryMaxY = screens[0].frame.maxY
        CGWarpMouseCursorPosition(CGPoint(x: centre.x, y: primaryMaxY - centre.y))
        // Warping leaves the pointer where it was put but does not redraw it
        // anywhere obvious, so it is worth pointing at.
        flashSpotlight()
        return true
    }

    /// Dims everything but a circle round the pointer, briefly.
    func flashSpotlight(duration: TimeInterval = 1.1) {
        spotlightToken += 1
        let generation = spotlightToken
        overlay.show(.spotlight(radius: Self.spotlightRadius), at: NSEvent.mouseLocation, tint: tint)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, spotlightToken == generation else { return }
            refreshPersistent()
        }
    }

    // MARK: - Tap

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard !suspended else { return }
        switch type {
        case .leftMouseDown, .rightMouseDown:
            guard highlightEnabled else { return }
            let point = event.unflippedLocation
            DispatchQueue.main.async { [weak self] in self?.flashClick(at: point) }
        case .mouseMoved, .leftMouseDragged:
            guard crosshairsEnabled, spotlightToken == 0 || !overlay.isSpotlighting else { return }
            let point = event.unflippedLocation
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                overlay.show(.crosshairs, at: point, tint: tint)
            }
        default:
            break
        }
    }

    private func flashClick(at point: NSPoint) {
        overlay.pulse(at: point, radius: Self.clickRadius, tint: tint)
    }

    /// Back to whatever should be on screen when nothing transient is showing.
    private func refreshPersistent() {
        // Only ever draws behind a live tap. Without one the crosshairs could
        // never follow the pointer, and painting them anyway would freeze a
        // cross across every display with nothing to move it.
        guard !suspended, tap != nil else {
            overlay.hide()
            return
        }
        if crosshairsEnabled {
            overlay.show(.crosshairs, at: NSEvent.mouseLocation, tint: tint)
        } else {
            overlay.hide()
        }
    }
}

private extension CGEvent {
    /// CG events are in top-left space; AppKit windows are in bottom-left.
    var unflippedLocation: NSPoint {
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        return NSPoint(x: location.x, y: primaryMaxY - location.y)
    }
}
