import AppKit
import Carbon.HIToolbox

final class QuickShotCanvas: NSView {
    private enum Gesture {
        case create(from: CGPoint)
        case adjust(from: CGPoint, original: CGRect, handle: CGPoint)
    }

    private let bitmap: ShotBitmap
    private let safeArea: CGRect
    private let backdrop: QuickShotBackdrop
    private var selection: CGRect?
    private var gesture: Gesture?
    private var pointerArea: NSTrackingArea?
    private let toolbar = QuickShotToolbar()
    private let dimensions = QuickShotDimensions()
    var onCancel: (() -> Void)?
    var onSelect: (() -> Void)?
    var onEditor: ((NSImage) -> Void)?

    init(bitmap: ShotBitmap, safeArea: CGRect) {
        self.bitmap = bitmap
        self.safeArea = safeArea
        let frame = CGRect(origin: .zero, size: bitmap.displaySize)
        backdrop = QuickShotBackdrop(image: bitmap.image, frame: frame)
        super.init(frame: frame)
        toolbar.addSubview(QuickShotButton(symbol: "xmark", title: .commonCancel, cancel: true) { [weak self] in
            self?.onCancel?()
        })
        toolbar.addSubview(QuickShotButton(symbol: "macwindow", title: .shotAfterEditor) { [weak self] in
            self?.openEditor()
        })
        addSubview(backdrop)
        addSubview(dimensions)
        addSubview(toolbar)
        refresh()
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var geometry: ShotSelection { ShotSelection(pixels: bitmap.size, view: bounds.size) }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let pointerArea { removeTrackingArea(pointerArea) }
        let area = NSTrackingArea(rect: .zero, options: [.activeInActiveApp, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        pointerArea = area
    }

    override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard !toolbarContains(point) else { return }
        guard let selection else { return NSCursor.crosshair.set() }
        let handle = geometry.handle(at: point, of: selection)
        if handle != .zero {
            resizeCursor(for: handle).set()
        } else {
            (geometry.viewRect(selection).contains(point) ? NSCursor.openHand : .crosshair).set()
        }
    }

    private func resizeCursor(for handle: CGPoint) -> NSCursor {
        if #available(macOS 15, *) {
            if handle.x == 0 { return .rowResize(directions: .all) }
            if handle.y == 0 { return .columnResize(directions: .all) }
            let corner: NSCursor.FrameResizePosition = handle.y < 0
                ? (handle.x < 0 ? .topLeft : .topRight)
                : (handle.x < 0 ? .bottomLeft : .bottomRight)
            return .frameResize(position: corner, directions: .all)
        }
        return handle.x == 0 ? .resizeUpDown : .resizeLeftRight
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard !toolbarContains(point) else { return }
        window?.makeFirstResponder(self)
        if let selection {
            let handle = geometry.handle(at: point, of: selection)
            if handle != .zero || geometry.viewRect(selection).contains(point) {
                gesture = .adjust(from: geometry.pixelPoint(point), original: selection, handle: handle)
                if handle == .zero { NSCursor.closedHand.set() }
                return
            }
        }
        onSelect?()
        clearSelection()
        gesture = .create(from: point)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        switch gesture {
        case .create(let start):
            selection = geometry.selection(from: start, to: point)
        case .adjust(let start, let original, let handle):
            let current = geometry.pixelPoint(point)
            let delta = CGPoint(x: current.x - start.x, y: current.y - start.y)
            selection = handle == .zero ? geometry.move(original, by: delta)
                : geometry.resize(original, handle: handle, by: delta)
        case nil:
            return
        }
        refresh()
    }

    override func mouseUp(with event: NSEvent) {
        mouseDragged(with: event)
        gesture = nil
        refresh()
        mouseMoved(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Escape {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    func clearSelection() {
        gesture = nil
        selection = nil
        refresh()
    }

    private func toolbarContains(_ point: CGPoint) -> Bool {
        !toolbar.isHidden && toolbar.frame.contains(point)
    }

    private func refresh() {
        backdrop.selection = selection.map(geometry.viewRect)
        toolbar.isHidden = selection == nil
        if case .create = gesture { toolbar.isHidden = true }
        dimensions.isHidden = selection == nil
        guard let selection else { return }
        let size = dimensions.fittedSize(for: selection)
        let barSize = toolbar.fittedSize(availableWidth: safeArea.width - 10)
        let position = QuickShotLayout.place(dimensions: size, toolbar: barSize,
                                            selection: geometry.viewRect(selection), area: safeArea)
        dimensions.frame = position.dimensions
        toolbar.frame = position.toolbar
    }

    private func openEditor() {
        guard let selection, let image = bitmap.crop(selection) else { return }
        onEditor?(image)
    }
}
