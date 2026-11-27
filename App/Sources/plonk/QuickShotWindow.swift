import AppKit

final class QuickShotWindow: NSWindow {
    let canvas: QuickShotCanvas
    var onRegionPointerChange: ((CGPoint) -> Void)?
    private var interactingWithStyle = false

    init(screen: NSScreen, bitmap: ShotBitmap, fixed: Bool, model: AppModel, annotation: ShotAnnotationState) {
        let frame = screen.frame
        let visible = screen.visibleFrame
        let safeArea = CGRect(x: visible.minX - frame.minX, y: frame.maxY - visible.maxY,
                              width: visible.width, height: visible.height)
        canvas = QuickShotCanvas(bitmap: bitmap, size: frame.size, safeArea: safeArea, fixed: fixed,
                                 model: model, annotation: annotation)
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

    func canvasPoint(at screenPoint: CGPoint) -> CGPoint {
        canvas.convert(convertPoint(fromScreen: screenPoint), from: nil)
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, attachedSheet == nil {
            interactingWithStyle = canvas.handlesStyleClick(at: event.locationInWindow)
            if !interactingWithStyle, canvas.selectDimension(at: event.locationInWindow) { return }
        }
        super.sendEvent(event)
        if event.type == .leftMouseUp, interactingWithStyle {
            interactingWithStyle = false
            makeFirstResponder(canvas)
        }
        switch event.type {
        case .leftMouseDown, .leftMouseDragged, .leftMouseUp:
            onRegionPointerChange?(convertPoint(toScreen: event.locationInWindow))
        default:
            break
        }
    }

    func shortcut(for event: NSEvent) -> ShotKeyCommand? {
        guard isKeyWindow, (event.window == nil || event.window === self),
              attachedSheet == nil, firstResponder === canvas else { return nil }
        return ShotKeyCommand(keyCode: Int(event.keyCode), characters: event.charactersIgnoringModifiers,
                              flags: event.modifierFlags, repeating: event.isARepeat)
    }
}
