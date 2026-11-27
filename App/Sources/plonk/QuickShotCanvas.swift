import AppKit
import Combine

final class QuickShotCanvas: NSView {
    private enum Gesture {
        case create(from: CGPoint, desktopClick: Bool)
        case adjust(from: CGPoint, original: CGRect, handle: CGPoint)
        case mark
    }

    private let bitmap: ShotBitmap
    private let annotation: ShotAnnotationState
    private let safeArea: CGRect
    private let fixed: Bool
    private let backdrop: QuickShotBackdrop
    private let markup: QuickShotMarkupView
    private var selectionHint: QuickShotHint?
    private var history = AnnotationHistory()
    private var selection: CGRect?
    private var aspectRatio: CGFloat?
    private var gesture: Gesture?
    private var pointerArea: NSTrackingArea?
    private lazy var controls = QuickShotControls(fixed: fixed, safeArea: safeArea) { [weak self] in self?.perform($0) }
    private var accentObservation: AnyCancellable?
    var onCancel: (() -> Void)?
    var onSelect: (() -> Void)?
    var onSelectionStateChange: (() -> Void)?
    var isDesktop: ((CGPoint) -> Bool)?
    var onSelectDisplay: (() -> Void)?
    var marksAnywhere: (() -> Bool)?
    var onOutput: ((QuickShotOutput, ShotCrop) -> Void)?

    init(bitmap: ShotBitmap, size: CGSize, safeArea: CGRect, fixed: Bool, model: AppModel = AppModel(),
         annotation: ShotAnnotationState? = nil) {
        self.bitmap = bitmap
        self.annotation = annotation ?? ShotAnnotationState(defaults: model.config.shotAnnotationStyles)
        self.safeArea = safeArea
        self.fixed = fixed
        let frame = CGRect(origin: .zero, size: size)
        backdrop = QuickShotBackdrop(image: bitmap.image, frame: frame, fixed: fixed)
        markup = QuickShotMarkupView(frame: frame)
        super.init(frame: frame)
        if fixed {
            wantsLayer = true
            layer?.backgroundColor = NSColor(calibratedWhite: 0.11, alpha: 1).cgColor
            selection = CGRect(origin: .zero, size: bitmap.size)
        }
        addSubview(backdrop)
        addSubview(markup)
        controls.views.forEach { addSubview($0) }
        accentObservation = model.$config.map(\.appearance).removeDuplicates().sink { [weak self] appearance in
            self?.controls.toolbar.accent = appearance.accent
        }
        let dimensions = controls.dimensions
        dimensions.canvas = self
        dimensions.onResize = { [weak self] value, horizontal in
            guard let self, let selection else { return }
            let resized = geometry.resize(selection, dimension: CGFloat(value), horizontal: horizontal,
                                          ratio: aspectRatio)
            self.selection = resized
            refresh()
            if Int(horizontal ? resized.width : resized.height) != value {
                HUD.shared.show(.shotSelectionFitted(Int(resized.width), Int(resized.height)))
            }
        }
        dimensions.onToggleLock = { [weak self] in
            guard let self, let selection else { return }
            aspectRatio = aspectRatio == nil ? selection.width / selection.height : nil
            refresh()
        }
        dimensions.onSizeChange = { [weak self] in
            guard let self, let selection else { return }
            controls.place(over: geometry.viewRect(selection), annotation: self.annotation,
                           toolbarSize: controls.toolbar.frame.size)
        }
        refresh()
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    var hasMarks: Bool { history.canUndo || history.canRedo }
    var isWaitingForSelection: Bool { !fixed && selection == nil && gesture == nil }

    private var geometry: ShotSelection { ShotSelection(pixels: bitmap.size, view: bounds.size) }

    func installSelectionHint(canRestore: Bool) {
        let hint = QuickShotHint(in: safeArea, canRestore: canRestore)
        selectionHint = hint
        addSubview(hint)
    }

    func showSelectionHint(_ visible: Bool) {
        selectionHint?.isHidden = !visible
    }

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
        guard !controls.contains(point) else { return }
        if fixed {
            (annotation.tool != nil && backdrop.frame.contains(point) ? NSCursor.crosshair : .arrow).set()
            return
        }
        guard let selection else { return NSCursor.crosshair.set() }
        let handle = geometry.handle(at: point, of: selection)
        if handle != .zero {
            resizeCursor(for: handle).set()
        } else {
            let moving = annotation.tool == nil && geometry.viewRect(selection).contains(point)
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
        guard !controls.contains(point) else { return }
        if let window {
            if !window.isKeyWindow { window.makeKey() }
            window.makeFirstResponder(self)
        }
        if fixed {
            if backdrop.frame.contains(point) { beginMark(at: point) }
            return
        }
        let handle = selection.map { geometry.handle(at: point, of: $0) } ?? .zero
        let inside = selection.map { geometry.viewRect($0).contains(point) } ?? false
        let marksExist = marksAnywhere?() ?? hasMarks
        switch QuickShotPress(handle: handle, insideSelection: inside, drawing: annotation.tool != nil, marksExist: marksExist) {
        case .mark:
            beginMark(at: point)
        case .adjust(let handle):
            guard let selection else { return }
            gesture = .adjust(from: geometry.pixelPoint(point), original: selection, handle: handle)
            if handle == .zero { NSCursor.closedHand.set() }
        case .select:
            let desktopClick = isWaitingForSelection && isDesktop?(point) == true
            clearSelection()
            gesture = .create(from: point, desktopClick: desktopClick)
            onSelect?()
        case .ignore:
            return
        }
    }

    private func beginMark(at point: CGPoint) {
        let start = ImageFit.unitPoint(point, in: backdrop.frame)
        guard annotation.beginMark(in: &history, at: start, viewWidth: backdrop.frame.width) else { return }
        gesture = .mark
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        switch gesture {
        case .create(let start, let desktopClick):
            gesture = .create(from: start, desktopClick: desktopClick && point == start)
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
        let point = convert(event.locationInWindow, from: nil)
        if case .mark = gesture {
            history.end(at: ImageFit.unitPoint(point, in: backdrop.frame))
        } else if case .create(let start, true) = gesture, point == start {
            gesture = nil
            onSelectDisplay?()
        } else {
            mouseDragged(with: event)
        }
        gesture = nil
        onSelectionStateChange?()
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
        case .selectDisplay, .restoreRegion: break
        }
    }

    @discardableResult
    func selectRegion(_ rect: CGRect) -> Bool {
        guard isWaitingForSelection else { return false }
        selection = rect
        onSelect?()
        refresh()
        return true
    }

    func selectEntireDisplay() {
        selectRegion(CGRect(origin: .zero, size: bitmap.size))
    }

    func clearSelection() {
        guard !fixed else { return }
        gesture = nil
        selection = nil
        aspectRatio = nil
        history = AnnotationHistory()
        annotation.tool = nil
        refresh()
    }

    func selectDimension(at point: CGPoint) -> Bool {
        controls.dimensions.selectField(at: point)
    }

    func handlesStyleClick(at windowPoint: CGPoint) -> Bool {
        controls.handlesStyleClick(at: convert(windowPoint, from: nil))
    }

    private func refresh() {
        controls.toolbar.update(tool: annotation.tool, history: history)
        if fixed {
            let frame = controls.placeFixed(imageSize: bitmap.displaySize, annotation: annotation)
            backdrop.frame = frame
            markup.frame = frame
            markup.show(history, clippedTo: markup.bounds)
            return
        }

        let frame = selection.map(geometry.viewRect)
        backdrop.selection = frame
        markup.show(history, clippedTo: frame)
        let isCreating = if case .create = gesture { true } else { false }
        controls.showRegion(hasSelection: selection != nil, isCreating: isCreating)
        guard let selection, let frame else { return }
        controls.dimensions.update(size: selection.size, locked: aspectRatio != nil)
        controls.place(over: frame, annotation: annotation)
    }

    private func perform(_ action: QuickShotToolbar.Action) {
        window?.makeFirstResponder(self)
        switch action {
        case .tool(let choice): annotation.tool = annotation.tool == choice ? nil : choice
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
