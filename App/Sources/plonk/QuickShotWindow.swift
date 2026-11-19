import AppKit
import Carbon.HIToolbox

final class QuickShotWindow: NSWindow {
    let canvas: QuickShotCanvas
    var onCancel: (() -> Void)?

    init(screen: NSScreen, bitmap: ShotBitmap) {
        let frame = screen.frame
        let visible = screen.visibleFrame
        canvas = QuickShotCanvas(bitmap: bitmap, frame: CGRect(origin: .zero, size: frame.size),
                                safeArea: CGRect(x: visible.minX - frame.minX, y: frame.maxY - visible.maxY,
                                                 width: visible.width, height: visible.height))
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(frame, display: false)
        level = .screenSaver
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = canvas
        initialFirstResponder = canvas
        autorecalculatesKeyViewLoop = true
        canvas.onCancel = { [weak self] in self?.onCancel?() }
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) { onCancel?() }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, firstResponder === canvas {
            switch Int(event.keyCode) {
            case kVK_Escape:
                onCancel?()
                return
            case kVK_Return, kVK_ANSI_KeypadEnter, kVK_Space:
                canvas.output(save: false)
                return
            default: break
            }
        }
        super.sendEvent(event)
    }
}
