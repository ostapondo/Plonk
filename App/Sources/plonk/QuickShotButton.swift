import AppKit

final class QuickShotButton: NSButton {
    private let invoke: () -> Void

    init(symbol: String, title: LocalizedStringResource, cancel: Bool = false, invoke: @escaping () -> Void) {
        self.invoke = invoke
        super.init(frame: .zero)
        let label = String(localized: title)
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?
            .withSymbolConfiguration(.init(pointSize: 17, weight: .medium))
        imagePosition = .imageOnly
        isBordered = false
        contentTintColor = cancel ? NSColor(srgbRed: 1, green: 115 / 255, blue: 123 / 255, alpha: 1)
            : NSColor(srgbRed: 238 / 255, green: 241 / 255, blue: 245 / 255, alpha: 1)
        focusRingType = .exterior
        toolTip = label
        setAccessibilityLabel(label)
        target = self
        action = #selector(activate)
    }

    required init?(coder: NSCoder) { nil }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: isEnabled ? .pointingHand : .arrow)
    }

    @objc private func activate() { invoke() }
}
