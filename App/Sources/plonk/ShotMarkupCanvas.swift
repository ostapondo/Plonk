import AppKit

class ShotMarkupCanvas: NSView {
    private(set) var history: AnnotationHistory
    var onHistoryChanged: ((AnnotationHistory) -> Void)?
    var tool: Annotation.Kind?
    var colorIndex = 0
    var strokePoints: Double = 4

    private let preview = ShotMarkupPreview(rootView: ShotMarkupLayer())
    private var textEntry: ShotTextEntry?
    private var textMark: Annotation?

    init(frame: CGRect, history: AnnotationHistory = AnnotationHistory()) {
        self.history = history
        super.init(frame: frame)
        addSubview(preview)
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    var imageRect: CGRect { bounds }
    var markupClip: CGRect { imageRect }

    override func layout() {
        super.layout()
        updateMarkup()
        if let textEntry, let point = textMark?.points.first {
            textEntry.frame = textFrame(at: point)
        }
    }

    func updateMarkup() {
        preview.frame = bounds
        preview.rootView = ShotMarkupLayer(history: history, imageRect: imageRect, clip: markupClip)
    }

    @discardableResult
    func beginMark(at point: CGPoint) -> Bool {
        guard let tool, markupClip.contains(point), imageRect.width > 0 else { return false }
        let unit = ImageFit.unitPoint(point, in: imageRect)
        if tool == .text {
            beginText(at: unit)
        } else {
            history.begin(tool, at: unit, color: colorIndex, width: strokePoints / imageRect.width)
            updateMarkup()
        }
        return true
    }

    @discardableResult
    func dragMark(to point: CGPoint) -> Bool {
        guard history.live != nil else { return false }
        history.drag(to: ImageFit.unitPoint(point, in: imageRect))
        updateMarkup()
        return true
    }

    @discardableResult
    func endMark(at point: CGPoint) -> Bool {
        guard let last = history.live?.points.last else { return false }
        if last != ImageFit.unitPoint(point, in: imageRect) { dragMark(to: point) }
        history.end()
        changedHistory()
        return true
    }

    func undoMark() {
        history.undo()
        changedHistory()
    }

    func redoMark() {
        history.redo()
        changedHistory()
    }

    private func changedHistory() {
        updateMarkup()
        onHistoryChanged?(history)
    }

    private func beginText(at point: CGPoint) {
        let fontSize = max(12, strokePoints * 3 + 6)
        let entry = ShotTextEntry(frame: textFrame(at: point))
        entry.font = .systemFont(ofSize: fontSize)
        entry.drawsBackground = true
        entry.backgroundColor = .textBackgroundColor
        entry.textContainerInset = NSSize(width: 4, height: 4)
        entry.isRichText = false
        entry.isAutomaticQuoteSubstitutionEnabled = false
        entry.allowsUndo = true
        entry.setAccessibilityLabel(String(localized: .toolText))
        entry.onCommit = { [weak self] in self?.commitText() }
        entry.onCancel = { [weak self] in self?.cancelText() }
        textMark = Annotation(kind: .text, points: [point], colorIndex: colorIndex, width: fontSize / imageRect.width)
        textEntry = entry
        addSubview(entry)
        window?.makeFirstResponder(entry)
    }

    private func textFrame(at point: CGPoint) -> CGRect {
        let size = CGSize(width: min(bounds.width, 270), height: min(bounds.height, 88))
        let x = point.x * imageRect.width + imageRect.minX
        let y = point.y * imageRect.height + imageRect.minY
        return CGRect(x: min(x, bounds.maxX - size.width), y: min(y, bounds.maxY - size.height),
                      width: size.width, height: size.height)
    }

    @discardableResult
    func commitText() -> Bool {
        guard let entry = textEntry, var mark = textMark else { return true }
        guard !entry.hasMarkedText() else { return false }
        if !entry.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mark.text = entry.string
            history.append(mark)
        }
        cancelText()
        changedHistory()
        return true
    }

    @discardableResult
    func cancelText() -> Bool {
        guard let textEntry else { return false }
        if window?.firstResponder === textEntry { window?.makeFirstResponder(self) }
        textEntry.removeFromSuperview()
        self.textEntry = nil
        textMark = nil
        return true
    }
}
