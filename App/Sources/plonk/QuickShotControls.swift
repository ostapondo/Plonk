import AppKit

final class QuickShotControls: NSObject, NSTextFieldDelegate {
    let dimensions = QuickShotSurface(radius: 9, insets: NSEdgeInsets(top: 3, left: 7, bottom: 3, right: 9))
    let toolbar = QuickShotSurface(radius: 16, insets: NSEdgeInsets(top: 4, left: 7, bottom: 4, right: 7))
    var onResize: ((Int, Bool) -> Void)?
    var onLock: ((Bool) -> Void)?
    var onCancel: (() -> Void)?
    var onAction: ((QuickShotAction) -> Void)?
    var onEndEditing: (() -> Void)?

    private let widthField = NSTextField()
    private let heightField = NSTextField()
    private let lock = NSButton()
    private var width = 0
    private var height = 0

    override init() {
        super.init()
        setup(widthField, title: .shotSelectionWidth)
        setup(heightField, title: .shotSelectionHeight)
        let pixels = NSTextField(labelWithString: String(localized: .shotSelectionPixels))
        pixels.font = .systemFont(ofSize: 11, weight: .medium)
        pixels.textColor = .secondaryLabelColor
        Self.configure(lock, symbol: "lock.open", title: .shotSelectionLock, target: self, action: #selector(toggleLock))
        lock.setButtonType(.toggle)
        for view in [widthField, lock, heightField, pixels] { dimensions.stack.addArrangedSubview(view) }
        addButton(symbol: "xmark", title: .commonCancel, action: #selector(cancel))
        addButton(symbol: "macwindow", title: .shotAfterEditor, action: #selector(openEditor))
        addButton(symbol: "square.and.arrow.down", title: .shotEditorSaveToFolder, action: #selector(save))
        addButton(symbol: "document.on.document", title: .shotEditorCopy, action: #selector(copyImage))
    }

    private func setup(_ field: NSTextField, title: LocalizedStringResource) {
        field.isEditable = true
        field.isSelectable = true
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .exterior
        field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        field.alignment = .center
        field.setAccessibilityLabel(String(localized: title))
        field.toolTip = String(localized: title)
        field.delegate = self
        field.widthAnchor.constraint(equalToConstant: 42).isActive = true
    }

    static func configure(_ button: NSButton, symbol: String, title: LocalizedStringResource,
                          target: AnyObject, action: Selector) {
        let label = String(localized: title)
        button.image = icon(symbol, label: label)
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

    static func icon(_ symbol: String, label: String) -> NSImage? {
        NSImage(systemSymbolName: symbol, accessibilityDescription: label)?
            .withSymbolConfiguration(.init(pointSize: 15, weight: .medium))
    }

    @discardableResult
    func addButton(symbol: String, title: LocalizedStringResource, action: Selector) -> NSButton {
        let button = NSButton()
        Self.configure(button, symbol: symbol, title: title, target: self, action: action)
        toolbar.stack.addArrangedSubview(button)
        return button
    }

    func update(width: Int, height: Int) {
        self.width = width
        self.height = height
        widthField.stringValue = String(width)
        heightField.stringValue = String(height)
    }

    func place(around rect: CGRect, in area: CGRect) {
        let top = dimensions.stack.fittingSize
        let bottom = toolbar.stack.fittingSize
        let gap: CGFloat = 7
        let topY = max(area.minY + gap, rect.minY - top.height - gap)
        var bottomY = rect.maxY + gap
        if bottomY + bottom.height > area.maxY - gap {
            let above = topY - bottom.height - gap
            bottomY = above >= area.minY + gap ? above : rect.maxY - bottom.height - gap
        }
        if bottomY >= topY - bottom.height && bottomY < topY + top.height + gap {
            bottomY = topY + top.height + gap
        }
        dimensions.frame = CGRect(x: horizontalOrigin(rect.minX, width: top.width, in: area),
                                  y: topY, width: top.width, height: top.height)
        toolbar.frame = CGRect(x: horizontalOrigin(rect.minX, width: bottom.width, in: area),
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
        lock.image = Self.icon(lock.state == .on ? "lock" : "lock.open",
                               label: String(localized: .shotSelectionLock))
    }

    @objc private func toggleLock() {
        updateLock()
        onLock?(lock.state == .on)
    }

    @objc private func openEditor() { onAction?(.editor) }
    @objc private func save() { onAction?(.save) }
    @objc private func copyImage() { onAction?(.copy) }
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
