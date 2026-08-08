import AppKit

// Four small things for the cursor, all of them a transparent click-through
// window and an event tap that only ever reads.
//
// - Find it: tap Control twice and everything but a circle around the pointer
//   dims, so a cursor lost on a wide desk is found without waggling the mouse.
// - Highlight clicks: a coloured ring on every press. This is for anyone
//   recording a demo — a click is invisible in a screen recording otherwise.
// - Crosshairs: full-width and full-height lines through the pointer, for
//   lining things up and for anyone who needs the cursor to be findable
//   all the time rather than on demand.
// - Jump: a hotkey warps the pointer to the middle of the next screen, which
//   beats shoving a mouse across three monitors.

final class MouseTools {
    /// Two Control presses inside this window count as the summon gesture.
    private static let doubleTapWindow: TimeInterval = 0.4
    private static let spotlightRadius: CGFloat = 110
    private static let clickRadius: CGFloat = 34

    private let overlay = MouseOverlay()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastControlRelease: Date?
    private var controlWasAlone = false
    private var spotlightToken = 0

    var findEnabled = false
    var highlightEnabled = false
    var crosshairsEnabled = false {
        didSet { refreshPersistent() }
    }
    var tint: NSColor = .controlAccentColor

    func start() {
        guard tap == nil else { return }
        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
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
        switch type {
        case .flagsChanged:
            guard findEnabled else { return }
            // The gesture is Control pressed and released twice, on its own.
            // Watching only for "the flags contain Control" would fire on every
            // Control chord — which is every shortcut Plonk itself ships.
            let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
                .intersection(.deviceIndependentFlagsMask)
            if flags == .control {
                controlWasAlone = true
                return
            }
            // Any other modifier joining in makes this a chord, not a tap.
            guard flags.isEmpty, controlWasAlone else {
                controlWasAlone = false
                lastControlRelease = nil
                return
            }
            controlWasAlone = false
            let now = Date()
            if let last = lastControlRelease, now.timeIntervalSince(last) < Self.doubleTapWindow {
                lastControlRelease = nil
                DispatchQueue.main.async { [weak self] in self?.flashSpotlight() }
            } else {
                lastControlRelease = now
            }
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
