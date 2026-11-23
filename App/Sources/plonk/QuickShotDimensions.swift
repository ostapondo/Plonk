import AppKit

final class QuickShotDimensions: NSView {
    private let label = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = QuickShotBackdrop.accent.cgColor
        layer?.cornerRadius = 5
        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        addSubview(label)
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        let height = label.intrinsicContentSize.height
        label.frame = CGRect(x: 0, y: bounds.midY - height / 2, width: bounds.width, height: height)
    }

    func fittedSize(for rect: CGRect) -> CGSize {
        label.stringValue = String(localized: .shotSelectionSize(Int(rect.width), Int(rect.height)))
        needsLayout = true
        return CGSize(width: label.intrinsicContentSize.width + 16, height: 29)
    }
}
