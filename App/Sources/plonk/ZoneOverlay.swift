import AppKit

// One borderless click-through window per screen that draws a zone set while a
// window is being dragged. Zones are numbered so a set with more than a couple
// of them can be told apart at a glance; the hovered one is emphasized.

final class ZoneOverlay {
    private let window: NSWindow
    private var zoneViews: [NSView] = []
    private var numbers: [NSTextField] = []
    private var layoutKey = ""

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
    func show(zones: [ZoneRect], highlighted: Set<Int>, visible: NSRect) {
        // Rebuilding subviews on every mouse move would drop frames, so the
        // geometry is only rebuilt when it actually changed.
        let key = "\(visible)|" + zones.map { "\($0.x),\($0.y),\($0.w),\($0.h)" }.joined(separator: ";")
        if key != layoutKey {
            layoutKey = key
            window.setFrame(visible, display: false)
            rebuild(zones: zones, visible: visible)
        }
        for (index, view) in zoneViews.enumerated() {
            let isHovered = highlighted.contains(index)
            view.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(isHovered ? 0.28 : 0.10).cgColor
            view.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(isHovered ? 0.9 : 0.35).cgColor
            view.layer?.borderWidth = isHovered ? 2 : 1.5
            if numbers.indices.contains(index) {
                numbers[index].textColor = NSColor.controlAccentColor.withAlphaComponent(isHovered ? 0.95 : 0.4)
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
        let numbered = zones.count > 1

        for (index, z) in zones.enumerated() {
            let rect = NSRect(
                x: z.x * visible.width,
                y: visible.height - (z.y + z.h) * visible.height,
                width: z.w * visible.width,
                height: z.h * visible.height
            ).insetBy(dx: 5, dy: 5)

            let view = NSView(frame: rect)
            view.wantsLayer = true
            view.layer?.cornerRadius = 10
            window.contentView?.addSubview(view)
            zoneViews.append(view)

            guard numbered else { continue }
            let label = NSTextField(labelWithString: "\(index + 1)")
            label.font = .systemFont(ofSize: numberSize(in: rect), weight: .bold)
            label.alignment = .center
            label.sizeToFit()
            label.frame = NSRect(x: 0, y: (rect.height - label.frame.height) / 2,
                                 width: rect.width, height: label.frame.height)
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
