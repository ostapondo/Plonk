import AppKit

// One borderless click-through window per screen that draws a zone set while a
// window is being dragged. Zones are numbered so a set with more than a couple
// of them can be told apart at a glance; the hovered one is emphasized. While
// ⌃⌥Z is held the same window takes clicks instead, and the zone clicked is
// where the front window goes; see DragSnapManager+Pick.

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
    private let window: NSPanel
    private var zoneViews: [NSView] = []
    /// Set while the zones are there to be clicked. A picture the rest of the
    /// time, so a drag over it reaches the window underneath.
    var interactive = false {
        didSet {
            window.ignoresMouseEvents = !interactive
            window.acceptsMouseMovedEvents = interactive
        }
    }
    /// The zone clicked, and the zone under the pointer or nil off all of them.
    var onPick: ((Int) -> Void)?
    var onHover: ((Int?) -> Void)?
    private var numbers: [NSTextField] = []
    /// A zone's name under its number, by zone index, for the zones that have one.
    private var names: [Int: NSTextField] = [:]
    private var lastZones: [ZoneRect] = []
    private var lastVisible = NSRect.zero
    private var appearance = ZoneAppearance()

    init() {
        // A panel that never activates: a click on a zone must not bring
        // Plonk forward, or the window it is for would lose focus to it.
        window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .transient]
        let content = ZoneOverlayView(frame: .zero)
        content.wantsLayer = true
        content.overlay = self
        window.contentView = content
    }

    /// The smallest zone drawn under a point in the window, so overlapping
    /// sets are clickable the way they are droppable.
    func zoneIndex(at point: NSPoint) -> Int? {
        var hit: (index: Int, area: CGFloat)?
        for (index, view) in zoneViews.enumerated() where view.frame.contains(point) {
            let area = view.frame.width * view.frame.height
            if hit == nil || area < hit!.area { hit = (index, area) }
        }
        return hit?.index
    }

    /// `highlighted` is a set rather than one index because a span covers
    /// several zones at once and all of them have to read as the drop target.
    func show(zones: [ZoneRect], highlighted: Set<Int>, visible: NSRect,
              appearance: ZoneAppearance = ZoneAppearance()) {
        // Rebuilding subviews on every mouse move would drop frames, so the
        // geometry is only rebuilt when it actually changed.
        if zones != lastZones || visible != lastVisible || appearance != self.appearance {
            lastZones = zones
            lastVisible = visible
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
            let ink = tint.withAlphaComponent((isHovered ? 0.95 : 0.4) * alpha)
            if numbers.indices.contains(index) { numbers[index].textColor = ink }
            names[index]?.textColor = ink
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
        names = [:]
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

            // The number, and the name under it; the two are centred as one
            // block, so a named zone reads as a label rather than a number
            // with something stuck to it. A name is drawn whether or not the
            // numbers are: it was asked for by name.
            let size = numberSize(in: gapped)
            let label = numbered ? NSTextField(labelWithString: "\(index + 1)") : nil
            label?.font = .systemFont(ofSize: size, weight: .bold)
            let name = z.name.map { NSTextField(labelWithString: $0) }
            name?.font = .systemFont(ofSize: max(13, size * 0.36), weight: .semibold)
            name?.lineBreakMode = .byTruncatingTail
            for field in [label, name].compactMap({ $0 }) {
                field.alignment = .center
                field.sizeToFit()
                field.autoresizingMask = [.width]
                view.addSubview(field)
            }
            let block = (label?.frame.height ?? 0) + (name?.frame.height ?? 0)
            let top = (gapped.height + block) / 2
            label?.frame = NSRect(x: 0, y: top - (label?.frame.height ?? 0),
                                  width: gapped.width, height: label?.frame.height ?? 0)
            name?.frame = NSRect(x: 0, y: top - block, width: gapped.width, height: name?.frame.height ?? 0)
            if let label { numbers.append(label) }
            if let name { names[index] = name }
        }
    }

    /// Scaled to the zone, so a narrow column does not get a number wider than it is.
    private func numberSize(in rect: NSRect) -> CGFloat {
        min(96, max(22, min(rect.width, rect.height) * 0.34))
    }
}

/// The overlay's content: nothing to draw of its own, but the one place a
/// click or a hover on the zones arrives.
final class ZoneOverlayView: NSView {
    weak var overlay: ZoneOverlay?

    /// The first click counts: the panel is never key, so without this the
    /// click that lands on a zone would only be asked to make it so.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let overlay, overlay.interactive,
              let zone = overlay.zoneIndex(at: convert(event.locationInWindow, from: nil)) else { return }
        overlay.onPick?(zone)
    }

    override func mouseMoved(with event: NSEvent) {
        guard let overlay, overlay.interactive else { return }
        overlay.onHover?(overlay.zoneIndex(at: convert(event.locationInWindow, from: nil)))
    }
}
