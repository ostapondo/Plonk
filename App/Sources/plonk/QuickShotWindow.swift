import AppKit

final class QuickShotWindow: NSWindow {
    let canvas: QuickShotCanvas

    init(screen: NSScreen, bitmap: ShotBitmap, fixed: Bool) {
        let frame = screen.frame
        let visible = screen.visibleFrame
        let safeArea = CGRect(x: visible.minX - frame.minX, y: frame.maxY - visible.maxY,
                              width: visible.width, height: visible.height)
        canvas = QuickShotCanvas(bitmap: bitmap, size: frame.size, safeArea: safeArea, fixed: fixed)
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(frame, display: false)
        isReleasedWhenClosed = false
        level = .screenSaver
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = canvas
        initialFirstResponder = canvas
    }

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, attachedSheet == nil, canvas.selectDimension(at: event.locationInWindow) {
            return
        }
        super.sendEvent(event)
    }

    func handleShortcut(_ event: NSEvent) -> Bool {
        guard isKeyWindow, (event.window == nil || event.window === self),
              attachedSheet == nil, firstResponder === canvas,
              let command = ShotKeyCommand(keyCode: Int(event.keyCode),
                                           characters: event.charactersIgnoringModifiers,
                                           flags: event.modifierFlags,
                                           repeating: event.isARepeat) else { return false }
        canvas.handle(command)
        return true
    }
}
