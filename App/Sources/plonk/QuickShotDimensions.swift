import AppKit

final class QuickShotDimensions: NSView, NSTextFieldDelegate {
    var onResize: ((Int, Bool) -> Void)?
    var onToggleLock: (() -> Void)?
    weak var canvas: NSView?

    private let widthField = QuickShotDimensionField(title: .shotSelectionWidth)
    private let heightField = QuickShotDimensionField(title: .shotSelectionHeight)
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
        let pixels = NSTextField(labelWithString: String(localized: .shotSelectionPixels))
        pixels.font = .systemFont(ofSize: 12)
        pixels.textColor = NSColor.white.withAlphaComponent(0.9)
        widthField.delegate = self
        heightField.delegate = self
        for view in [widthField, lock, heightField, pixels] { addSubview(view) }
        widthField.frame = CGRect(x: 6, y: 3, width: 42, height: 23)
        lock.frame = CGRect(x: 51, y: 3, width: 22, height: 23)
        heightField.frame = CGRect(x: 76, y: 3, width: 42, height: 23)
        let label = pixels.intrinsicContentSize
        // The label's intrinsic width leaves no room for the cell's horizontal text inset.
        pixels.frame = CGRect(x: 121, y: (29 - label.height) / 2 - 2,
                              width: label.width.rounded(.up) + 4, height: label.height)
        setFrameSize(CGSize(width: pixels.frame.maxX + 9, height: 29))
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }

    func update(size: CGSize, locked: Bool) {
        self.size = size
        for field in [widthField, heightField] where field.currentEditor() == nil {
            restore(field)
        }
        lock.isLocked = locked
    }

    func selectField(at windowPoint: CGPoint) -> Bool {
        guard !isHidden else { return false }
        let point = convert(windowPoint, from: nil)
        guard let field = [widthField, heightField].first(where: { $0.frame.contains(point) }),
              field.currentEditor() == nil else { return false }
        field.selectText(nil)
        return true
    }

    private func value(_ text: String) -> Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)), value > 0 else { return nil }
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
        guard let value = value(text) else {
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
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard !endingExplicitly, let field = notification.object as? NSTextField else { return }
        if let value = value(field.stringValue) { apply(value, to: field) }
        restore(field)
    }
}
