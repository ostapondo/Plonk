import AppKit

final class QuickShotControls: NSObject, NSTextFieldDelegate {
    let dimensions = NSStackView()
    let toolbar = NSStackView()
    var onResize: ((Int, Bool) -> Void)?
    var onLock: ((Bool) -> Void)?
    var onCancel: (() -> Void)?
    var onOutput: ((Bool) -> Void)?
    var onEndEditing: (() -> Void)?

    private let widthField = NSTextField()
    private let heightField = NSTextField()
    private let lock = NSButton()
    private var width = 0
    private var height = 0

    override init() {
        super.init()
        for stack in [dimensions, toolbar] {
            stack.orientation = .horizontal
            stack.alignment = .centerY
            stack.spacing = 4
            stack.edgeInsets = NSEdgeInsets(top: 5, left: 6, bottom: 5, right: 6)
            stack.wantsLayer = true
            stack.layer?.cornerRadius = 9
            stack.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            stack.layer?.borderColor = NSColor.separatorColor.cgColor
            stack.layer?.borderWidth = 1
        }
        setup(widthField, title: .shotSelectionWidth)
        setup(heightField, title: .shotSelectionHeight)
        dimensions.addArrangedSubview(widthField)
        dimensions.addArrangedSubview(NSTextField(labelWithString: "×"))
        dimensions.addArrangedSubview(heightField)
        dimensions.addArrangedSubview(NSTextField(labelWithString: String(localized: .shotSelectionPixels)))
        Self.configure(lock, symbol: "lock.open", title: .shotSelectionLock, target: self, action: #selector(toggleLock))
        lock.setButtonType(.toggle)
        dimensions.addArrangedSubview(lock)
        addButton(symbol: "square.and.arrow.down", title: .shotEditorSaveToFolder, action: #selector(save))
        addButton(symbol: "document.on.document", title: .shotEditorCopy, action: #selector(copyImage))
        addButton(symbol: "xmark", title: .commonCancel, action: #selector(cancel))
    }

    private func setup(_ field: NSTextField, title: LocalizedStringResource) {
        field.isEditable = true
        field.isSelectable = true
        field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        field.alignment = .center
        field.setAccessibilityLabel(String(localized: title))
        field.toolTip = String(localized: title)
        field.delegate = self
        field.widthAnchor.constraint(equalToConstant: 56).isActive = true
    }

    private static func configure(_ button: NSButton, symbol: String, title: LocalizedStringResource,
                                  target: AnyObject, action: Selector) {
        let label = String(localized: title)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        button.imagePosition = .imageOnly
        button.bezelStyle = .regularSquare
        button.controlSize = .small
        button.isBordered = false
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.target = target
        button.action = action
        button.widthAnchor.constraint(equalToConstant: 24).isActive = true
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true
    }

    @discardableResult
    func addButton(symbol: String, title: LocalizedStringResource, action: Selector) -> NSButton {
        let button = NSButton()
        Self.configure(button, symbol: symbol, title: title, target: self, action: action)
        toolbar.addArrangedSubview(button)
        return button
    }

    func update(width: Int, height: Int) {
        self.width = width
        self.height = height
        widthField.stringValue = String(width)
        heightField.stringValue = String(height)
    }

    func place(around rect: CGRect, in area: CGRect) {
        let top = dimensions.fittingSize
        let bottom = toolbar.fittingSize
        let gap: CGFloat = 5
        let topY = max(area.minY + gap, rect.minY - top.height - gap)
        var bottomY = rect.maxY + gap
        if bottomY + bottom.height > area.maxY - gap { bottomY = rect.maxY - bottom.height - gap }
        if bottomY < topY + top.height + gap { bottomY = topY + top.height + gap }
        dimensions.frame = CGRect(x: horizontalOrigin(rect.minX, width: top.width, in: area),
                                  y: topY, width: top.width, height: top.height)
        toolbar.frame = CGRect(x: horizontalOrigin(rect.maxX - bottom.width, width: bottom.width, in: area),
                               y: min(bottomY, area.maxY - bottom.height - gap),
                               width: bottom.width, height: bottom.height)
    }

    private func horizontalOrigin(_ x: CGFloat, width: CGFloat, in area: CGRect) -> CGFloat {
        min(max(x, area.minX + 5), max(area.minX + 5, area.maxX - width - 5))
    }

    func resetLock() {
        lock.state = .off
        updateLock()
    }

    private func updateLock() {
        lock.image = NSImage(systemSymbolName: lock.state == .on ? "lock" : "lock.open",
                             accessibilityDescription: String(localized: .shotSelectionLock))
    }

    @objc private func toggleLock() {
        updateLock()
        onLock?(lock.state == .on)
    }

    @objc private func save() { onOutput?(true) }
    @objc private func copyImage() { onOutput?(false) }
    @objc private func cancel() { onCancel?() }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard !textView.hasMarkedText() else { return false }
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            guard let value = Int(textView.string.trimmingCharacters(in: .whitespaces)), value > 0 else {
                HUD.shared.show(.shotSelectionInvalid)
                return true
            }
            onEndEditing?()
            onResize?(value, control === widthField)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            onEndEditing?()
            return true
        default: return false
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        update(width: width, height: height)
    }
}
