import AppKit

final class QuickShotHint: NSView {
    init(in safeArea: CGRect, canRestore: Bool) {
        let keys: [LocalizedStringResource] = canRestore
            ? [.shotSelectDisplayHint, .shotRestoreRegionHint] : [.shotSelectDisplayHint]
        let labels = keys.map { key in
            let label = NSTextField(labelWithString: String(localized: key))
            label.font = .systemFont(ofSize: 14, weight: .semibold)
            label.textColor = .white
            label.sizeToFit()
            return label
        }
        let padding = CGSize(width: 12, height: 8)
        var y = padding.height
        for label in labels.reversed() {
            label.setFrameOrigin(CGPoint(x: padding.width, y: y))
            y += label.frame.height
        }
        let size = CGSize(width: (labels.map { $0.frame.width }.max() ?? 0) + 2 * padding.width,
                          height: y + padding.height)
        // The flipped canvas puts its bottom edge at maxY.
        let origin = CGPoint(x: safeArea.minX + 12, y: safeArea.maxY - 12 - size.height)
        super.init(frame: CGRect(origin: origin, size: size))
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.86).cgColor
        layer?.cornerRadius = 7
        labels.forEach { addSubview($0) }
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
