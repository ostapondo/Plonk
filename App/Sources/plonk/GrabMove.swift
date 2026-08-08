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
// The tap only claims events while the modifier is down and a window is under
// the cursor; everything else passes through untouched.

final class GrabMove {
    /// Screen-relative sixths decide the grab handle: the middle band is an
    /// edge, the ends are corners.
    private static let cornerFraction: CGFloat = 0.3
    /// A window narrower than this cannot be usefully resized any further.
    private static let minimumSide: CGFloat = 80

    private let windows: WindowManager
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private struct Grab {
        let window: AXUIElement
        let startFrame: CGRect
        let startPoint: CGPoint
        /// nil while moving; the edge being pulled while resizing.
        let handle: Handle?
    }

    /// Which edges of the window the drag has hold of.
    struct Handle: Equatable {
        var left = false
        var right = false
        var top = false
        var bottom = false

        var isEmpty: Bool { !left && !right && !top && !bottom }
    }

    private var grab: Grab?

    var enabled = false
    /// The key held to take hold of a window. Option by default, as on Windows.
    var modifierFlag: NSEvent.ModifierFlags = .option
    var allowResize = true
    var showGeometry = true
    var isExcluded: ((NSRunningApplication) -> Bool)?
    /// Announced while a grab is in flight, so zones can light up under it.
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
            callback: { proxy, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<GrabMove>.fromOpaque(context).takeUnretainedValue()
                return manager.handle(proxy: proxy, type: type, event: event)
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
        grab = nil
    }

    // MARK: - Tap

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The tap is disabled by the system if it ever takes too long. Turning
        // it back on is the documented recovery, and losing it silently would
        // strand every future drag.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard enabled else { return Unmanaged.passUnretained(event) }

        let held = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue)).contains(modifierFlag)
        let point = event.location

        switch type {
        case .leftMouseDown, .rightMouseDown:
            guard held else { break }
            if type == .rightMouseDown && !allowResize { break }
            guard begin(at: point, resizing: type == .rightMouseDown) else { break }
            return nil
        case .leftMouseDragged, .rightMouseDragged:
            guard grab != nil else { break }
            // Letting go of the modifier mid-drag keeps the grab: the window is
            // already following the cursor, and dropping it would be startling.
            drag(to: point)
            return nil
        case .leftMouseUp, .rightMouseUp:
            guard let finished = grab else { break }
            grab = nil
            let resized = finished.handle != nil
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if resized {
                    onGrabResized?(finished.window, finished.startFrame)
                } else {
                    onGrabEnded?(finished.window, finished.startFrame)
                }
                if showGeometry { HUD.shared.hide() }
            }
            return nil
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    // MARK: - Grabbing

    /// True when a window was taken hold of, which is also when the click is
    /// swallowed rather than passed to the app.
    private func begin(at point: CGPoint, resizing: Bool) -> Bool {
        guard let window = windows.window(at: point) else { return false }
        if let app = windows.app(ofWindow: window), isExcluded?(app) == true { return false }
        guard let frame = windows.frame(ofWindow: window) else { return false }

        let handle = resizing ? Self.handle(for: point, in: frame) : nil
        if resizing && handle?.isEmpty != false { return false }
        grab = Grab(window: window, startFrame: frame, startPoint: point, handle: handle)
        // Only a move is handed to the zones. A resize that ended over a zone
        // would otherwise be thrown away and replaced by the zone's rect.
        if !resizing {
            DispatchQueue.main.async { [weak self] in self?.onGrabBegan?(window, frame) }
        }
        return true
    }

    private func drag(to point: CGPoint) {
        guard let grab else { return }
        let delta = CGVector(dx: point.x - grab.startPoint.x, dy: point.y - grab.startPoint.y)
        let frame = grab.handle.map { Self.resized(grab.startFrame, by: delta, pulling: $0) }
            ?? grab.startFrame.offsetBy(dx: delta.dx, dy: delta.dy)
        let resizing = grab.handle != nil
        // Setting a frame is synchronous IPC into the other app, and drawing
        // the readout builds a view. Neither may happen inside the tap
        // callback: the system disables a tap that takes too long, and every
        // drag after that would leak through to whatever is underneath.
        DispatchQueue.main.async { [weak self] in
            guard let self, let current = self.grab, CFEqual(current.window, grab.window) else { return }
            windows.setFrame(frame, ofWindow: current.window)
            if showGeometry {
                HUD.shared.showCompact("\(Int(frame.width)) × \(Int(frame.height))")
            }
            if !resizing { onGrabMoved?() }
        }
    }

    // MARK: - Geometry

    /// Which edges a right-drag starting at this point takes hold of. The
    /// middle third of a side is that edge alone; the ends are its corners.
    static func handle(for point: CGPoint, in frame: CGRect) -> Handle {
        guard frame.width > 0, frame.height > 0 else { return Handle() }
        let fx = (point.x - frame.minX) / frame.width
        let fy = (point.y - frame.minY) / frame.height
        var handle = Handle()
        handle.left = fx < cornerFraction
        handle.right = fx > 1 - cornerFraction
        handle.top = fy < cornerFraction
        handle.bottom = fy > 1 - cornerFraction
        // Dead centre still resizes — from the nearest side, so a drag in the
        // middle of a window is never a no-op the user has to think about.
        if handle.isEmpty {
            if min(fx, 1 - fx) < min(fy, 1 - fy) {
                handle.left = fx < 0.5
                handle.right = !handle.left
            } else {
                handle.top = fy < 0.5
                handle.bottom = !handle.top
            }
        }
        return handle
    }

    /// The frame after pulling those edges by that much, never smaller than
    /// the minimum and never inside out.
    static func resized(_ frame: CGRect, by delta: CGVector, pulling handle: Handle) -> CGRect {
        var result = frame
        if handle.left {
            let dx = min(delta.dx, frame.width - minimumSide)
            result.origin.x += dx
            result.size.width -= dx
        } else if handle.right {
            result.size.width = max(frame.width + delta.dx, minimumSide)
        }
        if handle.top {
            let dy = min(delta.dy, frame.height - minimumSide)
            result.origin.y += dy
            result.size.height -= dy
        } else if handle.bottom {
            result.size.height = max(frame.height + delta.dy, minimumSide)
        }
        return result
    }
}
