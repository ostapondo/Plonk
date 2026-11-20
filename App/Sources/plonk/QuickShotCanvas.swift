import AppKit

final class QuickShotCanvas: NSView {
    private enum Gesture {
        case create(from: CGPoint)
        case adjust(from: CGPoint, original: CGRect, handle: CGPoint)
        case mark
    }

    private let bitmap: ShotBitmap
    private let safeArea: CGRect
    private let backdrop: QuickShotBackdrop
    private let markup: QuickShotMarkupView
    private var history = AnnotationHistory()
    private var tool: Annotation.Kind?
    private var selection: CGRect?
    private var aspectRatio: CGFloat?
    private var gesture: Gesture?
    private var pointerArea: NSTrackingArea?
    private lazy var toolbar = QuickShotToolbar { [weak self] in self?.perform($0) }
    private let dimensions = QuickShotDimensions()
    var onCancel: (() -> Void)?
    var onSelect: (() -> Void)?
    var marksAnywhere: (() -> Bool)?
    var onOutput: ((QuickShotOutput, ShotCrop) -> Void)?

    init(bitmap: ShotBitmap, safeArea: CGRect) {
        self.bitmap = bitmap
        self.safeArea = safeArea
        let frame = CGRect(origin: .zero, size: bitmap.displaySize)
        backdrop = QuickShotBackdrop(image: bitmap.image, frame: frame)
        markup = QuickShotMarkupView(frame: frame)
        super.init(frame: frame)
        addSubview(backdrop)
        addSubview(markup)
        addSubview(dimensions)
        addSubview(toolbar)
        dimensions.canvas = self
        dimensions.onResize = { [weak self] value, horizontal in
            guard let self, let selection else { return }
            self.selection = geometry.resize(selection, dimension: CGFloat(value), horizontal: horizontal,
                                             ratio: aspectRatio)
            refresh()
        }
        dimensions.onToggleLock = { [weak self] in
            guard let self, let selection else { return }
            aspectRatio = aspectRatio == nil ? selection.width / selection.height : nil
            refresh()
        }
        refresh()
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    var hasMarks: Bool { history.canUndo || history.canRedo }

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
        guard !controlsContain(point) else { return }
        guard let selection else { return NSCursor.crosshair.set() }
        let handle = geometry.handle(at: point, of: selection)
        if handle != .zero {
            resizeCursor(for: handle).set()
        } else {
            let moving = tool == nil && geometry.viewRect(selection).contains(point)
            (moving ? NSCursor.openHand : .crosshair).set()
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
        guard !controlsContain(point) else { return }
        window?.makeFirstResponder(self)
        let handle = selection.map { geometry.handle(at: point, of: $0) } ?? .zero
        let inside = selection.map { geometry.viewRect($0).contains(point) } ?? false
        let marksExist = marksAnywhere?() ?? hasMarks
        switch QuickShotPress(handle: handle, insideSelection: inside, drawing: tool != nil, marksExist: marksExist) {
        case .mark:
            beginMark(at: point)
        case .adjust(let handle):
            guard let selection else { return }
            gesture = .adjust(from: geometry.pixelPoint(point), original: selection, handle: handle)
            if handle == .zero { NSCursor.closedHand.set() }
        case .select:
            onSelect?()
            clearSelection()
            gesture = .create(from: point)
        case .ignore:
            return
        }
    }

    private func beginMark(at point: CGPoint) {
        guard let tool else { return }
        history.begin(tool, at: ImageFit.unitPoint(point, in: backdrop.frame),
                      color: tool == .highlight ? 2 : 0, width: 4 / backdrop.frame.width)
        gesture = .mark
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
                : geometry.resize(original, handle: handle, by: delta, ratio: aspectRatio)
        case .mark:
            history.drag(to: ImageFit.unitPoint(point, in: backdrop.frame))
        case nil:
            return
        }
        refresh()
    }

    override func mouseUp(with event: NSEvent) {
        if case .mark = gesture {
            history.end(at: ImageFit.unitPoint(convert(event.locationInWindow, from: nil), in: backdrop.frame))
        } else {
            mouseDragged(with: event)
        }
        gesture = nil
        refresh()
        mouseMoved(with: event)
    }

    func handle(_ command: ShotKeyCommand) {
        switch command {
        case .cancel: perform(.cancel)
        case .copy: perform(.output(.copy))
        case .save: perform(.output(.save))
        case .undo: perform(.undo)
        case .redo: perform(.redo)
        }
    }

    func clearSelection() {
        gesture = nil
        selection = nil
        aspectRatio = nil
        history = AnnotationHistory()
        tool = nil
        refresh()
    }

    func selectDimension(at point: CGPoint) -> Bool {
        dimensions.selectField(at: point)
    }

    private func controlsContain(_ point: CGPoint) -> Bool {
        (!toolbar.isHidden && toolbar.frame.contains(point)) ||
            (!dimensions.isHidden && dimensions.frame.contains(point))
    }

    private func refresh() {
        toolbar.update(tool: tool, history: history)
        let frame = selection.map(geometry.viewRect)
        backdrop.selection = frame
        markup.show(history, clippedTo: frame)
        toolbar.isHidden = selection == nil
        if case .create = gesture { toolbar.isHidden = true }
        dimensions.isHidden = selection == nil
        guard let selection, let frame else { return }
        dimensions.update(size: selection.size, locked: aspectRatio != nil)
        let barSize = toolbar.fittedSize(availableWidth: safeArea.width - 10)
        let position = QuickShotLayout.place(dimensions: dimensions.frame.size, toolbar: barSize,
                                            selection: frame, area: safeArea)
        dimensions.frame = position.dimensions
        toolbar.frame = position.toolbar
    }

    private func perform(_ action: QuickShotToolbar.Action) {
        window?.makeFirstResponder(self)
        switch action {
        case .tool(let choice): tool = tool == choice ? nil : choice
        case .undo: history.undo()
        case .redo: history.redo()
        case .cancel:
            onCancel?()
            return
        case .output(let action):
            guard let selection, gesture == nil else { return }
            guard let crop = ShotCrop(bitmap: bitmap, rect: selection, history: history) else {
                HUD.shared.show(.shotEditorRenderFailed)
                return
            }
            onOutput?(action, crop)
            return
        }
        refresh()
    }
}
