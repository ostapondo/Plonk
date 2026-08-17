import AppKit
import ApplicationServices

// Move and resize a window by dragging anywhere inside it, with a modifier
// held — no aiming for the title bar, no hunting for a two-pixel border.
//
// Hold the modifier and drag with the left button to move; drag with the right
// button to resize from whichever edge or corner the drag started nearest, so
// a window can be pulled from the side it is already on.
//
// This needs an event tap rather than a global monitor: the drags have to be
// swallowed, or the app underneath gets a click-and-drag it never asked for.
// Two rules keep that from eating anything it should not.
//
// Nothing slow happens inside the tap callback. Finding the window under the
// cursor and setting a frame are both synchronous IPC into another process,
// and a tap that takes too long is disabled by the system — after which every
// drag leaks through to whatever is underneath.
//
// A press that turns out to be a click is given back. Option-click means
// something in Finder, in the Dock and in half the apps on the machine, so the
// press is held, and if the mouse never travels far enough it is posted again
// for the app underneath to receive as the click it always was.

final class GrabMove {
    /// Screen-relative thirds decide the grab handle: the middle band is an
    /// edge, the ends are corners.
    static let cornerFraction: CGFloat = 0.3
    /// A window narrower than this cannot be usefully resized any further.
    static let minimumSide: CGFloat = 80
    /// Travel before a press counts as a drag rather than a click.
    private static let dragThreshold: CGFloat = 4
    /// Stamped on events this class posts itself, so the tap can tell them from
    /// the user's and let them past.
    private static let replayMarker: Int64 = 0x504C_4E4B  // "PLNK"

    private let windows: WindowManager
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private struct Grab {
        let window: AXUIElement
        let startFrame: CGRect
        let startPoint: CGPoint
        /// nil while moving; the edges being pulled while resizing.
        let handle: Handle?
        /// The swallowed press, kept until this is known to be a drag.
        let press: CGEvent
        /// True once the pointer has travelled far enough to be a drag rather
        /// than a click. Nothing is moved, and nothing is reported, before it.
        var moved: Bool
    }

    /// Which edges of the window the drag has hold of.
    struct Handle: Equatable {
        var left = false
        var right = false
        var top = false
        var bottom = false

        var isEmpty: Bool { !left && !right && !top && !bottom }
    }

    private enum State {
        case idle
        /// The button is down and the window is being looked up. The press is
        /// kept so it can be replayed if this turns out to be a click.
        case resolving(press: CGEvent, point: CGPoint, right: Bool, travelled: Bool)
        case grabbing(Grab)
        /// There was nothing to grab; the rest of this gesture is not ours.
        case passthrough
    }
    private var state: State = .idle

    var enabled = false
    /// The key held to take hold of a window. Option by default, as on Windows.
    var modifierFlag: NSEvent.ModifierFlags = .option
    var allowResize = true
    var showGeometry = true
    var isExcluded: ((NSRunningApplication) -> Bool)?
    /// Announced while a move is in flight, so zones can light up under it. A
    /// resize is never handed over: the zone's rect would replace it.
    var onGrabBegan: ((AXUIElement, CGRect) -> Void)?
    var onGrabMoved: (() -> Void)?
    var onGrabEnded: ((AXUIElement, CGRect) -> Void)?
    /// A resize finishing, which the zones never saw.
    var onGrabResized: ((AXUIElement, CGRect) -> Void)?

    init(windows: WindowManager) {
        self.windows = windows
    }

    /// Starts the tap. Silently does nothing without Accessibility, which is
    /// the same permission everything else here needs.
    /// Take the settings as they now stand, and arm or disarm accordingly. An
    /// event tap that can swallow clicks has no business existing while the
    /// feature is off, so the tap follows the setting rather than the launch.
    func apply(_ config: Config) {
        enabled = config.grabMoveEnabled
        modifierFlag = config.grabMoveModifierFlag
        allowResize = config.grabMoveResize
        showGeometry = config.grabMoveShowGeometry
        if config.grabMoveEnabled { start() } else { stop() }
    }

    func start() {
        guard tap == nil, windows.isTrusted else { return }
        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue)

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<GrabMove>.fromOpaque(context).takeUnretainedValue()
                return manager.handle(type: type, event: event)
            },
            userInfo: context
        ) else {
            NSLog("Plonk: could not create the grab-and-move event tap")
            return
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = source
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        runLoopSource = nil
        tap = nil
        state = .idle
    }

    // MARK: - Tap

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The tap is disabled by the system if it ever takes too long. Turning
        // it back on is the documented recovery, and losing it silently would
        // strand every future drag.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard enabled else { return Unmanaged.passUnretained(event) }
        // A press this class posted is the user's click arriving late; it must
        // not be caught a second time.
        if event.getIntegerValueField(.eventSourceUserData) == Self.replayMarker {
            return Unmanaged.passUnretained(event)
        }

        let point = event.location
        switch type {
        case .leftMouseDown, .rightMouseDown:
            let right = type == .rightMouseDown
            guard NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue)).contains(modifierFlag),
                  !(right && !allowResize),
                  let press = event.copy() else { break }
            state = .resolving(press: press, point: point, right: right, travelled: false)
            resolve(at: point, right: right)
            return nil

        case .leftMouseDragged, .rightMouseDragged:
            switch state {
            case .resolving(let press, let start, let right, let travelled):
                state = .resolving(press: press, point: start, right: right,
                                   travelled: travelled || moved(from: start, to: point))
                return nil
            case .grabbing(var grab):
                if !grab.moved {
                    guard moved(from: grab.startPoint, to: point) else { return nil }
                    grab.moved = true
                    state = .grabbing(grab)
                    // Only now is this a drag, and only now do the zones care.
                    if grab.handle == nil { onGrabBegan?(grab.window, grab.startFrame) }
                }
                drag(to: point)
                return nil
            default:
                break
            }

        case .leftMouseUp, .rightMouseUp:
            switch state {
            case .resolving(let press, _, _, let travelled):
                // The lookup never finished, so nothing moved. If it was a
                // click, hand it back.
                state = .idle
                if !travelled { replayClick(press) }
                return nil
            case .grabbing(let grab):
                state = .idle
                if grab.moved {
                    finish(grab)
                } else {
                    // The window was never touched: this was a click that
                    // happened to be over something grabbable.
                    replayClick(grab.press)
                }
                return nil
            case .passthrough:
                state = .idle
            case .idle:
                break
            }

        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    private func moved(from: CGPoint, to: CGPoint) -> Bool {
        abs(to.x - from.x) > Self.dragThreshold || abs(to.y - from.y) > Self.dragThreshold
    }

    // MARK: - Grabbing

    /// Finds the window under the press, off the tap's callback. Everything in
    /// here talks to another process and may block.
    private func resolve(at point: CGPoint, right: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self, case .resolving(let press, _, _, let travelled) = state else { return }
            // Nothing to grab. The press was swallowed to keep the callback
            // cheap, so it is posted again and the rest of the gesture — the
            // drags and the release — is left to travel normally.
            let hand: (CGEvent) -> Void = { [weak self] press in
                self?.state = .passthrough
                self?.replayPress(press)
            }
            guard let window = windows.window(at: point), let frame = windows.frame(ofWindow: window) else {
                hand(press)
                return
            }
            if let app = windows.app(ofWindow: window), isExcluded?(app) == true {
                hand(press)
                return
            }
            let handle = right ? Self.handle(for: point, in: frame) : nil
            if right, handle?.isEmpty != false {
                hand(press)
                return
            }
            state = .grabbing(Grab(window: window, startFrame: frame, startPoint: point,
                                   handle: handle, press: press, moved: travelled))
            // A drag that outran the lookup is already a drag.
            if travelled, !right { onGrabBegan?(window, frame) }
        }
    }

    private func drag(to point: CGPoint) {
        // Setting a frame is synchronous IPC into the other app, and the
        // readout draws; neither belongs in the tap callback.
        DispatchQueue.main.async { [weak self] in
            guard let self, case .grabbing(let grab) = state else { return }
            let frame = Self.frame(for: grab, at: point)
            windows.setFrame(frame, ofWindow: grab.window)
            if showGeometry {
                HUD.shared.showCompact("\(Int(frame.width)) × \(Int(frame.height))")
            }
            if grab.handle == nil { onGrabMoved?() }
        }
    }

    private func finish(_ grab: Grab) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if showGeometry { HUD.shared.hide() }
            if grab.handle != nil {
                onGrabResized?(grab.window, grab.startFrame)
            } else {
                onGrabEnded?(grab.window, grab.startFrame)
            }
        }
    }

    private static func frame(for grab: Grab, at point: CGPoint) -> CGRect {
        let delta = CGVector(dx: point.x - grab.startPoint.x, dy: point.y - grab.startPoint.y)
        return grab.handle.map { resized(grab.startFrame, by: delta, pulling: $0) }
            ?? grab.startFrame.offsetBy(dx: delta.dx, dy: delta.dy)
    }

    /// Posts a swallowed press back while the button is still down, so the
    /// gesture carries on where it belongs. Marked, or the tap would catch it
    /// again.
    private func replayPress(_ press: CGEvent) {
        press.setIntegerValueField(.eventSourceUserData, value: Self.replayMarker)
        press.post(tap: .cgSessionEventTap)
    }

    /// Posts a swallowed press back as the whole click it turned out to be.
    /// The release is synthesized because the real one was consumed on the way
    /// here — this is only ever called from the mouse-up handler.
    private func replayClick(_ press: CGEvent) {
        guard let release = press.copy() else { return }
        release.type = press.type == .rightMouseDown ? .rightMouseUp : .leftMouseUp
        for event in [press, release] {
            event.setIntegerValueField(.eventSourceUserData, value: Self.replayMarker)
            event.post(tap: .cgSessionEventTap)
        }
    }
}
