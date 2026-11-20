import AppKit

final class QuickShotAspectLock: NSButton {
    private let invoke: () -> Void
    var isLocked = false {
        didSet {
            guard isLocked != oldValue else { return }
            image = isLocked ? Self.closedLock : Self.openLock
            setAccessibilityValue(NSNumber(value: isLocked))
        }
    }

    init(invoke: @escaping () -> Void) {
        self.invoke = invoke
        super.init(frame: .zero)
        let label = String(localized: .shotSelectionLock)
        imagePosition = .imageOnly
        isBordered = false
        image = Self.openLock
        if let cell = cell as? NSButtonCell {
            cell.highlightsBy = []
            cell.showsStateBy = []
        }
        wantsLayer = true
        layer?.cornerRadius = 4
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
                                       owner: self, userInfo: nil))
        toolTip = label
        setAccessibilityLabel(label)
        setAccessibilityValue(NSNumber(value: false))
        target = self
        action = #selector(activate)
    }

    required init?(coder: NSCoder) { nil }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(48 / 255).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = nil
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    @objc private func activate() { invoke() }

    private static let openLock = lockImage(closed: false)
    private static let closedLock = lockImage(closed: true)

    private static func lockImage(closed: Bool) -> NSImage {
        NSImage(size: CGSize(width: 19, height: 19), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            // Use the prototype's 24-unit path on its 19-point canvas.
            context.saveGState()
            context.scaleBy(x: 19 / 24, y: 19 / 24)
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(1.8)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.move(to: CGPoint(x: 8, y: 11))
            context.addLine(to: CGPoint(x: 8, y: 8))
            context.addArc(center: CGPoint(x: 12, y: 8), radius: 4, startAngle: .pi,
                           endAngle: closed ? 2 * .pi : 11 * .pi / 6, clockwise: false)
            if closed { context.addLine(to: CGPoint(x: 16, y: 11)) }
            context.addRect(CGRect(x: 7, y: 11, width: 10, height: 9))
            context.move(to: CGPoint(x: 12, y: 15))
            context.addLine(to: CGPoint(x: 12, y: 17))
            context.strokePath()
            context.restoreGState()
            return true
        }
    }
}
