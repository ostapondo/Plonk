import AppKit

// How the pointer tools draw themselves, worked out from the settings once.
// The tap, the overlay window and the view that paints it all read this rather
// than the config, the way ZoneAppearance works for the zones: a click ring
// and the crosshairs cannot end up disagreeing about a colour.
//
// Every colour falls back to the zone colour, which is the one all three were
// wired to before any of this was settable.

struct PointerAppearance: Equatable {
    /// What a click leaves behind. A ring is the least of it on a bright
    /// screen; a filled dot survives being scaled down into a demo video.
    enum ClickStyle: String, CaseIterable, Identifiable {
        case ring, dot, both

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .ring: return .mouseShapeRing
            case .dot: return .mouseShapeDot
            case .both: return .mouseShapeBoth
            }
        }
    }

    /// The zone colour: what finding the pointer draws with, and what every
    /// colour below falls back to.
    var tint: NSColor = .controlAccentColor
    var click: NSColor = .controlAccentColor
    var rightClick: NSColor = .controlAccentColor
    var clickRadius: CGFloat = 34
    var clickLineWidth: CGFloat = 3
    var clickStyle = ClickStyle.ring
    var clickFade: TimeInterval = 0.24
    var crosshair: NSColor = .controlAccentColor
    var crosshairLineWidth: CGFloat = 2
    var crosshairOpacity: CGFloat = 0.7
    var spotlightRadius: CGFloat = 110
    var spotlightDim: CGFloat = 0.55

    init() {}

    init(_ config: Config) {
        tint = ZoneAppearance(config).tint
        click = ZoneAppearance.color(fromHex: config.clickColorHex) ?? tint
        // The click colour rather than the tint: a right click that was given
        // no colour of its own is meant to look like a left click, wherever
        // that colour came from.
        rightClick = ZoneAppearance.color(fromHex: config.rightClickColorHex) ?? click
        clickRadius = CGFloat(config.clickRadius)
        clickLineWidth = CGFloat(config.clickLineWidth)
        clickStyle = ClickStyle(rawValue: config.clickStyle) ?? .ring
        clickFade = config.clickFadeSeconds
        crosshair = ZoneAppearance.color(fromHex: config.crosshairColorHex) ?? tint
        crosshairLineWidth = CGFloat(config.crosshairLineWidth)
        crosshairOpacity = CGFloat(config.crosshairOpacity)
        spotlightRadius = CGFloat(config.spotlightRadius)
        spotlightDim = CGFloat(config.spotlightDim)
    }

    func clickColor(right: Bool) -> NSColor { right ? rightClick : click }
}
