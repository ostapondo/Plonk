import AppKit

final class QuickShotWindow: NSWindow {
    let canvas: QuickShotCanvas

    init(screen: NSScreen, image: CGImage) {
        let frame = screen.frame
        let bitmap = ShotBitmap(image: image, displaySize: frame.size)
        canvas = QuickShotCanvas(bitmap: bitmap)
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(frame, display: false)
        isReleasedWhenClosed = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = canvas
        initialFirstResponder = canvas
    }

    override var canBecomeKey: Bool { true }
}
