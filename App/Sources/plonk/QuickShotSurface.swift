import AppKit

final class QuickShotSurface: NSVisualEffectView {
    let stack = NSStackView()

    init(radius: CGFloat, insets: NSEdgeInsets) {
        super.init(frame: .zero)
        material = .hudWindow
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = radius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        stack.frame = bounds
        stack.autoresizingMask = [.width, .height]
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 3
        stack.edgeInsets = insets
        addSubview(stack)
    }

    required init?(coder: NSCoder) { nil }
}
