import AppKit

// One borderless click-through window per screen that draws a zone set while a
// window is being dragged. Zones are numbered so a set with more than a couple
// of them can be told apart at a glance; the hovered one is emphasized.

/// How zones are drawn and how much room they leave. Kept together so the
/// overlay and the placement that follows a drop cannot drift apart.
struct ZoneAppearance: Equatable {
    /// Points of empty space left around each zone, in the drawing and in the
    /// window that lands there.
    var gap: CGFloat = 0
    var opacity: CGFloat = 1
    /// nil follows the system accent colour.
    var color: NSColor?
    var showNumbers = true

    /// How the overlay is drawn, worked out from the settings. One place, so
    /// the zone drawing and the pointer tools cannot end up a different
    /// colour from each other.
    init(_ config: Config) {
        gap = CGFloat(config.zoneGap)
        opacity = CGFloat(config.zoneOpacity)
        // Falls back to the app's accent, which itself falls back to the
        // system one, so the overlay is part of the theme.
        color = Self.color(fromHex: config.zoneColorHex)
            ?? Self.color(fromHex: config.appearance.accentHex)
        showNumbers = config.zoneNumbersVisible
    }

    init() {}

    /// One colour, for the things that are not a zone: the ruler and the
    /// pointer tools share it so the desk stays one colour.
    var tint: NSColor { color ?? .controlAccentColor }

    /// The colour of a particular zone. Colour is the zone number, so each gets
    /// its own hue — unless an explicit colour is set for the set, in which
    /// case that wins and the whole overlay is one colour, as it used to be.
    func tint(for index: Int) -> NSColor { color ?? Ink.zoneTint(index) }

    /// "#RRGGBB" as stored in config. Anything else is nil, which means the
    /// accent colour — a bad string in a hand-edited file should not be fatal.
    static func color(fromHex hex: String?) -> NSColor? {
        guard var text = hex?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                       green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255,
                       alpha: 1)
    }

    static func hex(from color: NSColor) -> String {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        return String(format: "#%02X%02X%02X",
                      Int((rgb.redComponent * 255).rounded()),
                      Int((rgb.greenComponent * 255).rounded()),
                      Int((rgb.blueComponent * 255).rounded()))
    }
}

final class ZoneOverlay {
    private let window: NSWindow
    private var zoneViews: [NSView] = []
    private var numbers: [NSTextField] = []
    private var layoutKey = ""
    private var appearance = ZoneAppearance()

    init() {
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .transient]
        let content = NSView(frame: .zero)
        content.wantsLayer = true
        window.contentView = content
    }

    /// `highlighted` is a set rather than one index because a span covers
    /// several zones at once and all of them have to read as the drop target.
    func show(zones: [ZoneRect], highlighted: Set<Int>, visible: NSRect,
              appearance: ZoneAppearance = ZoneAppearance()) {
        // Rebuilding subviews on every mouse move would drop frames, so the
        // geometry is only rebuilt when it actually changed.
        let key = "\(visible)|\(appearance.gap)|\(appearance.showNumbers)|"
            + zones.map { "\($0.x),\($0.y),\($0.w),\($0.h)" }.joined(separator: ";")
        if key != layoutKey || appearance != self.appearance {
            layoutKey = key
            self.appearance = appearance
            window.setFrame(visible, display: false)
            rebuild(zones: zones, visible: visible)
        }
        let alpha = max(0, min(appearance.opacity, 1))
        for (index, view) in zoneViews.enumerated() {
            let isHovered = highlighted.contains(index)
            // Per zone, not per set: the hue is the number.
            let tint = appearance.tint(for: index)
            view.layer?.backgroundColor = tint.withAlphaComponent((isHovered ? 0.28 : 0.10) * alpha).cgColor
            view.layer?.borderColor = tint.withAlphaComponent((isHovered ? 0.9 : 0.35) * alpha).cgColor
            view.layer?.borderWidth = isHovered ? 2 : 1.5
            if numbers.indices.contains(index) {
                numbers[index].textColor = tint.withAlphaComponent((isHovered ? 0.95 : 0.4) * alpha)
            }
        }
        if !window.isVisible { window.orderFrontRegardless() }
    }

    func hide() {
        window.orderOut(nil)
    }

    private func rebuild(zones: [ZoneRect], visible: NSRect) {
        zoneViews.forEach { $0.removeFromSuperview() }
        zoneViews = []
        numbers = []
        // A single zone is the edge-snap preview; there is nothing to tell apart.
        let numbered = appearance.showNumbers && zones.count > 1
        // The gap is drawn as well as applied, so the overlay is a preview of
        // where the window will actually land — which means it is clamped the
        // same way, or a wide gap on a narrow zone draws a rect that no window
        // will ever be given. And nothing but the gap: a layout with gap 0
        // draws zones that touch, because that is where its windows go.

        for (index, z) in zones.enumerated() {
            let rect = NSRect(
                x: z.x * visible.width,
                y: visible.height - (z.y + z.h) * visible.height,
                width: z.w * visible.width,
                height: z.h * visible.height
            )
            let gapped = ZoneGeometry.inset(rect, by: appearance.gap)

            let view = NSView(frame: gapped)
            view.wantsLayer = true
            view.layer?.cornerRadius = 10
            window.contentView?.addSubview(view)
            zoneViews.append(view)

            guard numbered else { continue }
            let label = NSTextField(labelWithString: "\(index + 1)")
            label.font = .systemFont(ofSize: numberSize(in: gapped), weight: .bold)
            label.alignment = .center
            label.sizeToFit()
            label.frame = NSRect(x: 0, y: (gapped.height - label.frame.height) / 2,
                                 width: gapped.width, height: label.frame.height)
            label.autoresizingMask = [.width]
            view.addSubview(label)
            numbers.append(label)
        }
    }

    /// Scaled to the zone, so a narrow column does not get a number wider than it is.
    private func numberSize(in rect: NSRect) -> CGFloat {
        min(96, max(22, min(rect.width, rect.height) * 0.34))
    }
}
