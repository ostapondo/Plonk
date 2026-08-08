import AppKit

// Drag out a rectangle on any screen and get it back in CG coordinates —
// origin top-left of the primary display, y downward, the space every capture
// API here already speaks.
//
// `screencapture -i` gives the same crosshair for free but only hands back a
// file, never where the file came from, and a live thumbnail needs the where.

final class RegionPicker {
    /// The smallest drag that counts. Below this it was a click, which is how
    /// people cancel without reaching for Escape.
    private static let minimumSide: CGFloat = 12

    private var windows: [PickerWindow] = []
    private var completion: ((CGRect?) -> Void)?
    /// Held for the length of the pick, since nothing else refers to it.
    private static var active: RegionPicker?

    /// Hands the user a crosshair. Calls back on the main queue with the rect,
    /// or nil if they cancelled.
    static func pick(completion: @escaping (CGRect?) -> Void) {
        active?.finish(with: nil)
        let picker = RegionPicker()
        active = picker
        picker.begin(completion: completion)
    }

    private func begin(completion: @escaping (CGRect?) -> Void) {
        self.completion = completion
        for screen in NSScreen.screens {
            let window = PickerWindow(screen: screen)
            window.onFinish = { [weak self] rect in self?.finish(with: rect) }
            window.orderFrontRegardless()
            windows.append(window)
        }
        // Without this the overlay takes the drag but the app never comes
        // forward, and the Escape key goes to whatever was in front.
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKey()
    }

    private func finish(with rect: CGRect?) {
        guard let completion else { return }
        self.completion = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        if RegionPicker.active === self { RegionPicker.active = nil }

        guard let rect, rect.width >= Self.minimumSide, rect.height >= Self.minimumSide else {
            completion(nil)
            return
        }
        completion(rect)
    }
}

/// One per screen. Draws the dimmed backdrop and the hole being dragged.
private final class PickerWindow: NSWindow {
    var onFinish: ((CGRect?) -> Void)?
    private let picker = PickerView()

    init(screen: NSScreen) {
        // The screen-taking initializer is a convenience one, so the frame is
        // set after construction rather than through it.
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = picker
        picker.onFinish = { [weak self] rect in self?.onFinish?(rect) }
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onFinish?(nil)
    }

    override func keyDown(with event: NSEvent) {
        // Escape is the documented way out; anything else is ignored so a
        // stray keystroke cannot leave the overlay up.
        if event.keyCode == 53 { onFinish?(nil) }
    }
}

private final class PickerView: NSView {
    var onFinish: ((CGRect?) -> Void)?
    private var anchor: NSPoint?
    private var current: NSPoint?

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        anchor = convert(event.locationInWindow, from: nil)
        current = anchor
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            anchor = nil
            current = nil
            needsDisplay = true
        }
        guard let selection = selectionInView(), let window else {
            onFinish?(nil)
            return
        }
        // View → screen → CG: the last step flips y, because CG puts the
        // origin at the top-left of the primary display.
        let inScreen = window.convertToScreen(convert(selection, to: nil))
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        onFinish?(CGRect(x: inScreen.minX, y: primaryMaxY - inScreen.maxY,
                         width: inScreen.width, height: inScreen.height))
    }

    private func selectionInView() -> NSRect? {
        guard let anchor, let current else { return nil }
        return NSRect(x: min(anchor.x, current.x), y: min(anchor.y, current.y),
                      width: abs(anchor.x - current.x), height: abs(anchor.y - current.y))
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setFillColor(NSColor.black.withAlphaComponent(0.28).cgColor)
        context.fill(bounds)
        guard let selection = selectionInView() else { return }
        context.setBlendMode(.clear)
        context.fill(selection)
        context.setBlendMode(.normal)
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(1.5)
        context.stroke(selection)
    }
}
