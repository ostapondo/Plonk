import AppKit

final class QuickShotButton: NSButton {
    private let invoke: () -> Void
    var isSelectedTool: Bool? {
        didSet {
            guard isSelectedTool != oldValue else { return }
            setAccessibilityValue(isSelectedTool.map { NSNumber(value: $0) })
        }
    }

    init(symbol: String, title: LocalizedStringResource, cancel: Bool = false, invoke: @escaping () -> Void) {
        self.invoke = invoke
        super.init(frame: .zero)
        let label = String(localized: title)
        imagePosition = .imageOnly
        isBordered = false
        contentTintColor = cancel ? NSColor(srgbRed: 1, green: 115 / 255, blue: 123 / 255, alpha: 1)
            : NSColor(srgbRed: 238 / 255, green: 241 / 255, blue: 245 / 255, alpha: 1)
        focusRingType = .exterior
        toolTip = label
        setAccessibilityLabel(label)
        setSymbol(symbol)
        target = self
        action = #selector(activate)
    }

    required init?(coder: NSCoder) { nil }

    func setSymbol(_ symbol: String) {
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: accessibilityLabel())?
            .withSymbolConfiguration(.init(pointSize: 17, weight: .medium))
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: isEnabled ? .pointingHand : .arrow)
    }

    @objc private func activate() { invoke() }
}
