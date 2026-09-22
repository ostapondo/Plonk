import AppKit
import SwiftUI

// Colour is the zone number.
//
// Muted categorical colours identify zones in the editor and drag overlay.
// Each supports white text at label size; the number carries the distinction
// when colour alone is not enough.
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
// Six is the ceiling. Past that the palette wraps and the number carries it.

extension Ink {
    /// The hue for a zone, by its zero-based index. Wraps past the sixth.
    /// These are dark enough for white labels in both appearances.
    static func zone(_ index: Int) -> Color {
        Color(zoneTint(index))
    }

    /// The AppKit twin, for the overlay, which draws into layers rather than
    /// SwiftUI. Same table, so the two surfaces cannot disagree.
    static func zoneTint(_ index: Int) -> NSColor {
        let palette: [(CGFloat, CGFloat, CGFloat)] = [
            (0xA6, 0x53, 0x3F),   // 1 · terracotta
            (0x8C, 0x69, 0x29),   // 2 · ochre
            (0x39, 0x77, 0x68),   // 3 · sea green
            (0x47, 0x69, 0x83),   // 4 · slate blue
            (0x63, 0x74, 0x38),   // 5 · moss
            (0xA0, 0x4E, 0x57),   // 6 · brick rose
        ]
        // A negative index would trap on the modulo, and zone numbers arrive
        // from config files and the HTTP API, so clamp rather than trust.
        let (r, g, b) = palette[max(0, index) % palette.count]
        return NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
    }

    /// A close tonal lift keeps large zones from reading as flat blocks.
    static func zoneGradient(_ index: Int) -> LinearGradient {
        LinearGradient(colors: [lighter(zone(index)), zone(index)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// White labels remain readable over both ends of each zone fill.
    static func zoneInk(_ index: Int) -> Color {
        .white
    }

    /// Toward ink: the same hue, more saturated and darker, for a glyph or a
    /// line on a light surface. Sun at full brightness is invisible there.
    static func deeper(_ color: Color) -> Color {
        rebuilt(color) { _, saturation, brightness in
            saturation = min(saturation + 0.15, 1)
            brightness = max(brightness - 0.22, 0)
        }
    }

    /// A small lift in HSB preserves hue without introducing a bright edge.
    static func lighter(_ color: Color) -> Color {
        rebuilt(color) { _, saturation, brightness in
            saturation = max(saturation - 0.02, 0)
            brightness = min(brightness + 0.03, 1)
        }
    }
}
