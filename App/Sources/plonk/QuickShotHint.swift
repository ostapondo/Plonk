import AppKit

final class QuickShotHint: NSView {
    init(in safeArea: CGRect) {
        let label = NSTextField(labelWithString: String(localized: .shotSelectDisplayHint))
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.sizeToFit()
        let padding = CGSize(width: 12, height: 8)
        label.frame.origin = CGPoint(x: padding.width, y: padding.height)
        let size = CGSize(width: label.frame.width + 2 * padding.width,
                          height: label.frame.height + 2 * padding.height)
        let margin = QuickShotLayout.controlInset
        // The flipped canvas puts its bottom edge at maxY.
        let origin = CGPoint(x: safeArea.minX + margin, y: safeArea.maxY - margin - size.height)
        super.init(frame: CGRect(origin: origin, size: size))
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.86).cgColor
        layer?.cornerRadius = 7
        addSubview(label)
        isHidden = true
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
