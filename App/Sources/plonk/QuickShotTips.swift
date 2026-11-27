import AppKit

final class QuickShotTips: NSView {
    private static let padding: CGFloat = 10
    private static let lineHeight: CGFloat = 19
    private static let textStyle: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "Inter-Regular", size: 16) ?? NSFont.systemFont(ofSize: 16),
        .foregroundColor: NSColor(srgbRed: 245 / 255, green: 245 / 255, blue: 245 / 255, alpha: 1),
    ]
    private let lines: [NSAttributedString]

    init(_ tips: [LocalizedStringResource]) {
        let titles = tips.map { String(localized: $0) }
        let lines = titles.map { NSAttributedString(string: $0, attributes: Self.textStyle) }
        self.lines = lines
        let width = lines.map { ceil($0.size().width) }.max() ?? 0
        super.init(frame: CGRect(x: 0, y: 0, width: width + 2 * Self.padding,
                                 height: CGFloat(lines.count) * Self.lineHeight + 2 * Self.padding))
        isHidden = true
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(titles.joined(separator: "\n"))
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 3, yRadius: 3).fill()
        for (index, line) in lines.enumerated() {
            let top = Self.padding + CGFloat(index) * Self.lineHeight
            line.draw(at: CGPoint(x: Self.padding, y: top + (Self.lineHeight - line.size().height) / 2))
        }
    }
}
