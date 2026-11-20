import AppKit

final class QuickShotWindow: NSWindow {
    let canvas: QuickShotCanvas

    init(screen: NSScreen, image: CGImage) {
        let frame = screen.frame
        let visible = screen.visibleFrame
        let bitmap = ShotBitmap(image: image, displaySize: frame.size)
        let safeArea = CGRect(x: visible.minX - frame.minX, y: frame.maxY - visible.maxY,
                              width: visible.width, height: visible.height)
        canvas = QuickShotCanvas(bitmap: bitmap, safeArea: safeArea)
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
}
