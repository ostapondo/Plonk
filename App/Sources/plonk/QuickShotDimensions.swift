import AppKit

final class QuickShotDimensions: NSView, NSTextFieldDelegate {
    private static let maximumInput = 9_999
    private static let maximumInputLength = String(maximumInput).utf16.count

    var onResize: ((Int, Bool) -> Void)?
    var onToggleLock: (() -> Void)?
    var onSizeChange: (() -> Void)?
    weak var canvas: NSView?

    private let widthField = QuickShotDimensionField(title: .shotSelectionWidth)
    private let heightField = QuickShotDimensionField(title: .shotSelectionHeight)
    private let pixels = NSTextField(labelWithString: String(localized: .shotSelectionPixels))
    private lazy var lock = QuickShotAspectLock { [weak self] in
        guard let self else { return }
        window?.makeFirstResponder(canvas)
        onToggleLock?()
    }
    private var size = CGSize.zero
    private var endingExplicitly = false

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = QuickShotBackdrop.accent.cgColor
        layer?.cornerRadius = 5
        pixels.font = .systemFont(ofSize: 16)
        pixels.textColor = NSColor.white.withAlphaComponent(0.9)
        widthField.delegate = self
        heightField.delegate = self
        for view in [widthField, lock, heightField, pixels] { addSubview(view) }
        layoutFields()
    }

    private func layoutFields() {
        // Measure gaps from the visible glyphs inside each control's hit area.
        let gap: CGFloat = 12
        let digitInset: CGFloat = 5
        let lockLeadingInset: CGFloat = 7
        let lockTrailingInset: CGFloat = 6
        let unitInset: CGFloat = 3
        widthField.frame = CGRect(x: gap - digitInset, y: 3,
                                  width: widthField.fittedWidth(maximumLength: Self.maximumInputLength), height: 23)
        lock.frame = CGRect(x: widthField.frame.maxX + gap - digitInset - lockLeadingInset, y: 3, width: 22, height: 23)
        heightField.frame = CGRect(x: lock.frame.maxX + gap - lockTrailingInset - digitInset, y: 3,
                                   width: heightField.fittedWidth(maximumLength: Self.maximumInputLength), height: 23)
        let label = pixels.intrinsicContentSize
        let baseline = widthField.frame.minY + widthField.textBaselineFromTop
        // The label's intrinsic width leaves no room for the cell's horizontal text inset.
        pixels.frame = CGRect(x: heightField.frame.maxX + gap / 2 - digitInset - unitInset,
                              y: baseline - pixels.firstBaselineOffsetFromTop,
                              width: label.width.rounded(.up) + 4, height: label.height)
        let size = CGSize(width: pixels.frame.maxX + gap - unitInset, height: 29)
        guard size != frame.size else { return }
        setFrameSize(size)
        onSizeChange?()
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }

    func update(size: CGSize, locked: Bool) {
        self.size = size
        for field in [widthField, heightField] where field.currentEditor() == nil {
            restore(field)
        }
        lock.isLocked = locked
        layoutFields()
    }

    func selectField(at windowPoint: CGPoint) -> Bool {
        guard !isHidden else { return false }
        let point = convert(windowPoint, from: nil)
        guard let field = [widthField, heightField].first(where: { $0.frame.contains(point) }),
              field.currentEditor() == nil else { return false }
        field.selectText(nil)
        return true
    }

    private func value(_ text: String, for field: NSTextField) -> Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)), value > 0,
              value <= Self.maximumInput || value == committedValue(for: field) else { return nil }
        return value
    }

    private func committedValue(for field: NSTextField) -> Int {
        Int(field === widthField ? size.width : size.height)
    }

    private func apply(_ value: Int, to field: NSTextField) {
        guard value != committedValue(for: field) else { return }
        onResize?(value, field === widthField)
    }

    private func restore(_ field: NSTextField) {
        field.stringValue = String(committedValue(for: field))
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField,
              let editor = field.currentEditor() as? NSTextView else { return }
        defer { layoutFields() }
        let text = editor.string
        let limit = Self.maximumInputLength
        guard !editor.hasMarkedText(), text.utf16.count > limit,
              text.allSatisfy({ $0.isASCII && $0.isNumber }) else { return }

        let selection = editor.selectedRange()
        editor.textStorage?.deleteCharacters(in: NSRange(location: limit, length: text.utf16.count - limit))
        let start = min(selection.location, limit)
        let end = min(NSMaxRange(selection), limit)
        editor.setSelectedRange(NSRange(location: start, length: end - start))
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard let field = control as? NSTextField, !textView.hasMarkedText() else { return false }
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            submit(field, text: textView.string)
        case #selector(NSResponder.insertTab(_:)), #selector(NSResponder.insertBacktab(_:)):
            if submit(field, text: textView.string) {
                (field === widthField ? heightField : widthField).selectText(nil)
            }
        case #selector(NSResponder.cancelOperation(_:)):
            endEditing(field)
        default:
            return false
        }
        return true
    }

    @discardableResult
    private func submit(_ field: NSTextField, text: String) -> Bool {
        guard let value = value(text, for: field) else {
            HUD.shared.show(.shotSelectionInvalid)
            return false
        }
        endEditing(field)
        apply(value, to: field)
        return true
    }

    private func endEditing(_ field: NSTextField) {
        endingExplicitly = true
        window?.makeFirstResponder(canvas)
        endingExplicitly = false
        restore(field)
        layoutFields()
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard !endingExplicitly, let field = notification.object as? NSTextField else { return }
        if let value = value(field.stringValue, for: field) { apply(value, to: field) }
        restore(field)
        layoutFields()
    }
}
