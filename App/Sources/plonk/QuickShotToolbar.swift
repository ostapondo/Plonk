import AppKit

final class QuickShotToolbar: NSView {
    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(srgbRed: 41 / 255, green: 45 / 255, blue: 52 / 255, alpha: 1).cgColor
        layer?.cornerRadius = 21
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.13).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.4
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -5)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(String(localized: .shotAfterQuickActions))
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {}

    func fittedSize(availableWidth: CGFloat) -> CGSize {
        let layout = QuickShotLayout.toolbar(dividers: subviews.map { !($0 is QuickShotButton) },
                                             availableWidth: availableWidth)
        for (view, slot) in zip(subviews, layout.frames) {
            view.frame = view is QuickShotButton ? slot
                : CGRect(x: slot.midX, y: slot.midY - 7.5, width: 1, height: 15)
        }
        return layout.size
    }
}
