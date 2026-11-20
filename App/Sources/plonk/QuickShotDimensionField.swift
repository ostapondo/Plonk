import AppKit

final class QuickShotDimensionField: NSTextField {
    init(title: LocalizedStringResource) {
        super.init(frame: .zero)
        isEditable = true
        isSelectable = true
        isBordered = false
        drawsBackground = false
        focusRingType = .none
        font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        textColor = .white
        alignment = .center
        if let cell = cell as? NSTextFieldCell { cell.usesSingleLineMode = true }
        let label = String(localized: title)
        setAccessibilityLabel(label)
        toolTip = label
        wantsLayer = true
        layer?.cornerRadius = 3
    }

    required init?(coder: NSCoder) { nil }

    override func textShouldBeginEditing(_ textObject: NSText) -> Bool {
        guard super.textShouldBeginEditing(textObject) else { return false }
        layer?.backgroundColor = NSColor(srgbRed: 0, green: 47 / 255, blue: 112 / 255, alpha: 1).cgColor
        return true
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        layer?.backgroundColor = nil
    }
}
