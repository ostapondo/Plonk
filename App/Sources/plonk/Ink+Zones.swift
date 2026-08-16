import AppKit
import SwiftUI

// Colour is the zone number.
//
// Zone 1 is rose, 2 plum, 3 blue, 4 mint, 5 sun — in the drag overlay, in the
// editor, in the menu bar panel, on the website and on the README. The colour
// is never decoration: it is the same fact as the digit, said a second way, so
// a set can be read at a glance before anyone reads a number.
//
// These are deliberately independent of the accent. The accent is chrome — it
// belongs to buttons, selection rings and the pointer tools, and one accent
// cannot tell five zones apart. This is a categorical palette, the same kind a
// chart uses for series, and it answers a different question.
//
// The user still has the last word: setting an explicit zone colour on the
// Zones page goes back to one colour for the whole set, exactly as before. Only
// the default changed.
//
// Six is the ceiling. Past that the hues stop being reliably distinguishable —
// especially for the ~8% of men with a red-green deficiency, for whom rose and
// mint are the risky pair — so the palette wraps and the number carries it.
// Rose and blue are the two that stay furthest apart on every kind of vision,
// which is why they are 1 and 3 rather than neighbours.

extension Ink {
    /// The hue for a zone, by its zero-based index. Wraps past the sixth.
    /// Values are the same hex the site and the README use, so a screenshot and
    /// a landing page can never drift apart.
    static func zone(_ index: Int) -> Color {
        Color(zoneTint(index))
    }

    /// The AppKit twin, for the overlay, which draws into layers rather than
    /// SwiftUI. Same table, so the two surfaces cannot disagree.
    static func zoneTint(_ index: Int) -> NSColor {
        let palette: [(CGFloat, CGFloat, CGFloat)] = [
            (0xFF, 0x4F, 0x81),   // 1 · rose
            (0x8B, 0x5C, 0xF6),   // 2 · plum
            (0x3A, 0x6B, 0xFF),   // 3 · blue
            (0x12, 0xD3, 0xA4),   // 4 · mint
            (0xFF, 0xC5, 0x31),   // 5 · sun
            (0x25, 0xC8, 0xFF),   // 6 · sky
        ]
        // A negative index would trap on the modulo, and zone numbers arrive
        // from config files and the HTTP API, so clamp rather than trust.
        let (r, g, b) = palette[max(0, index) % palette.count]
        return NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
    }

    /// The lighter end of a zone's gradient. The site fills each rectangle with
    /// a gradient rather than a flat colour, and this is the top-left stop.
    static func zoneGradient(_ index: Int) -> LinearGradient {
        LinearGradient(colors: [lighter(zone(index)), zone(index)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Toward white, in HSB, so a mint stays mint instead of turning grey the
    /// way a straight blend with white would.
    static func lighter(_ color: Color) -> Color {
        guard let base = NSColor(color).usingColorSpace(.deviceRGB) else { return color }
        return Color(NSColor(hue: base.hueComponent,
                             saturation: max(base.saturationComponent - 0.28, 0),
                             brightness: min(base.brightnessComponent + 0.16, 1),
                             alpha: base.alphaComponent))
    }
}
