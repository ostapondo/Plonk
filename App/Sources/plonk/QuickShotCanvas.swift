import AppKit

final class QuickShotCanvas: ShotMarkupCanvas {
    var onSelect: (() -> Void)?
    var onCancel: (() -> Void)?
    var onAction: ((NSImage, AnnotationHistory, QuickShotAction) -> Void)?

    private let bitmap: ShotBitmap
    private let backdrop: NSImage
    private let geometry: ShotSelection
    private let safeArea: CGRect
    private let controls = QuickShotControls()
    private let accent: NSColor
    private lazy var tools = ShotMarkupTools(canvas: self, kinds: [.rectangle, .ellipse, .arrow, .pen, .text],
                                            includeSelection: true, accent: accent)
    private var rect: CGRect? {
        didSet {
            if rect != oldValue { dismissRecognition() }
            refresh()
        }
    }
    private var recognitionToken = 0
    private var ratio: CGFloat?
    private var anchor = CGPoint.zero
    private var original: CGRect?
    private var handle = CGPoint.zero
    private var dragging = false

    init(bitmap: ShotBitmap, frame: CGRect, safeArea: CGRect, accent: NSColor) {
        self.bitmap = bitmap
        self.safeArea = safeArea
        self.accent = accent
        backdrop = NSImage(cgImage: bitmap.image, size: frame.size)
        geometry = ShotSelection(pixels: bitmap.size, view: frame.size)
        super.init(frame: frame)
        controls.toolbar.stack.insertArrangedSubview(tools.stack, at: 0)
        controls.toolbar.stack.setCustomSpacing(10, after: tools.stack)
        addSubview(controls.dimensions)
        addSubview(controls.toolbar)
        addSubview(controls.feedback)
        controls.onResize = { [weak self] value, horizontal in self?.resize(value, horizontal: horizontal) }
        controls.onLock = { [weak self] locked in
            self?.ratio = locked ? self?.rect.map { $0.width / $0.height } : nil
        }
        controls.onCancel = { [weak self] in self?.onCancel?() }
        controls.onAction = { [weak self] action in self?.perform(action) }
        controls.onEndEditing = { [weak self] in self?.window?.makeFirstResponder(self) }
        refresh()
    }

    required init?(coder: NSCoder) { nil }
    override var markupClip: CGRect { rect.map(geometry.viewRect) ?? .zero }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func clearSelection() {
        ratio = nil
        dragging = false
        controls.resetLock()
        rect = nil
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
        guard let rect else { return }
        addCursorRect(geometry.viewRect(rect), cursor: tool == .text ? .iBeam : tool == nil ? .openHand : .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        guard commitText() else { return }
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        anchor = geometry.pixelPoint(point)
        original = nil
        handle = .zero
        if let rect {
            let viewRect = geometry.viewRect(rect)
            if viewRect.insetBy(dx: -5, dy: -5).contains(point) {
                original = rect
                handle = edge(at: point, of: viewRect)
            }
        }
        if handle == .zero && beginMark(at: point) { return }
        if original == nil { clearSelection() }
        dragging = true
        onSelect?()
        refresh()
    }

    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if dragMark(to: location) { return }
        guard dragging else { return }
        let point = geometry.pixelPoint(location)
        let delta = CGPoint(x: point.x - anchor.x, y: point.y - anchor.y)
        if let original {
            rect = handle == .zero ? geometry.move(original, by: delta)
                : geometry.drag(original, handle: handle, delta: delta, ratio: ratio)
        } else {
            let selection = CGRect(spanning: anchor, point)
            rect = selection.isEmpty ? nil : selection
        }
    }

    override func mouseUp(with event: NSEvent) {
        if endMark(at: convert(event.locationInWindow, from: nil)) { return }
        guard dragging else { return }
        mouseDragged(with: event)
        dragging = false
        if let rect, original == nil {
            let viewRect = geometry.viewRect(rect)
            if viewRect.width < 3 || viewRect.height < 3 { self.rect = nil }
        }
        refresh()
        window?.invalidateCursorRects(for: self)
    }

    private func edge(at point: CGPoint, of rect: CGRect) -> CGPoint {
        func side(_ position: CGFloat, _ start: CGFloat, _ end: CGFloat) -> CGFloat {
            let distance = min(abs(position - start), abs(position - end))
            guard distance <= 5 else { return 0 }
            return position <= (start + end) / 2 ? -1 : 1
        }
        return CGPoint(x: side(point.x, rect.minX, rect.maxX), y: side(point.y, rect.minY, rect.maxY))
    }

    private func resize(_ dimension: Int, horizontal: Bool) {
        guard let rect else { return }
        self.rect = geometry.resize(rect, dimension: CGFloat(dimension), horizontal: horizontal, ratio: ratio)
        window?.invalidateCursorRects(for: self)
    }

    func perform(_ action: QuickShotAction) {
        guard controls.commitDimensions(), commitText(), let rect, let image = bitmap.crop(rect) else { return }
        let crop = CGRect(x: rect.minX / bitmap.size.width, y: rect.minY / bitmap.size.height,
                          width: rect.width / bitmap.size.width, height: rect.height / bitmap.size.height)
        onAction?(image, history.rebased(to: crop), action)
    }

    func selectTool(_ kind: Annotation.Kind) {
        guard rect != nil else { return }
        tools.select(kind)
    }

    func beginRecognition() -> Int {
        recognitionToken += 1
        controls.showFeedback(.shotRecognizing)
        refresh()
        return recognitionToken
    }

    func finishRecognition(_ result: Result<[TextExtractor.Line], Error>, token: Int) {
        guard recognitionToken == token else { return }
        switch result {
        case .success(let lines): controls.showFeedback(TextExtractor.copyRecognizedText(lines))
        case .failure: controls.showFeedback(.shotRecognitionFailed)
        }
        refresh()
    }

    @discardableResult
    func dismissRecognition() -> Bool {
        guard !controls.feedback.isHidden else { return false }
        recognitionToken += 1
        controls.showFeedback(nil)
        return true
    }

    private func refresh() {
        needsDisplay = true
        updateMarkup()
        controls.dimensions.isHidden = rect == nil
        controls.toolbar.isHidden = rect == nil || dragging
        guard let rect else { return }
        controls.update(width: Int(rect.width), height: Int(rect.height))
        controls.place(around: geometry.viewRect(rect), in: safeArea)
    }

    override func draw(_ dirtyRect: NSRect) {
        backdrop.draw(in: bounds, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
        let shade = NSBezierPath(rect: bounds)
        if let rect { shade.appendRect(geometry.viewRect(rect)) }
        shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.42).setFill()
        shade.fill()
        guard let rect else { return }
        let selection = geometry.viewRect(rect)
        let outline = NSBezierPath(rect: selection)
        accent.setStroke()
        outline.lineWidth = 1
        outline.stroke()
        drawHandles(of: selection)
    }

    private func drawHandles(of rect: CGRect) {
        let side = min(rect.width / 3, rect.height / 3, 11)
        guard side >= 2 else { return }
        let corners = NSBezierPath()
        for (x, dx) in [(rect.minX, side), (rect.maxX, -side)] {
            for (y, dy) in [(rect.minY, side), (rect.maxY, -side)] {
                corners.move(to: CGPoint(x: x + dx, y: y))
                corners.line(to: CGPoint(x: x, y: y))
                corners.line(to: CGPoint(x: x, y: y + dy))
            }
        }
        corners.lineWidth = 4
        corners.lineCapStyle = .round
        corners.lineJoinStyle = .round
        accent.setStroke()
        corners.stroke()
    }
}
