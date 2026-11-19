import AppKit

final class QuickShotWindow: NSWindow {
    let canvas: QuickShotCanvas
    var onCancel: (() -> Void)?

    init(screen: NSScreen, bitmap: ShotBitmap, accent: NSColor) {
        let frame = screen.frame
        let visible = screen.visibleFrame
        canvas = QuickShotCanvas(bitmap: bitmap, frame: CGRect(origin: .zero, size: frame.size),
                                safeArea: CGRect(x: visible.minX - frame.minX, y: frame.maxY - visible.maxY,
                                                 width: visible.width, height: visible.height),
                                accent: accent)
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

    func handleShortcut(_ event: NSEvent) -> Bool {
        guard let command = ShotKeyCommand(event: event, window: self, canvas: canvas) else { return false }
        switch command {
        case .cancel:
            if !canvas.cancelText() && !canvas.dismissRecognition() { onCancel?() }
        case .select(let kind): canvas.selectTool(kind)
        case .action(let action): canvas.perform(action)
        case .undo: canvas.undoMark()
        case .redo: canvas.redoMark()
        case .tab(let backward):
            if backward { selectPreviousKeyView(canvas) } else { selectNextKeyView(canvas) }
        }
        return true
    }
}
