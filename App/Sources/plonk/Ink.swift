import AppKit
import SwiftUI

// The look every page is built from: four surfaces, one hairline, one radius.
//
// The window is a dark ground. The sidebar is a panel set into it, a step
// darker; every card on a page is a step lighter. That order is the whole
// design: the menu recedes, the page comes forward, and the ground between them
// is what makes both read as things rather than as one flat sheet.
//
// Both themes are spelled out because the app has a theme of its own now: a
// window forced to light while the system is dark cannot ask NSColor what grey
// to use and get an answer that suits the window it is actually in.

enum Ink {
    static let radius: CGFloat = 16
    /// The sidebar panel's corner, and how far it sits from the window edge.
    static let panelRadius: CGFloat = 14
    static let inset: CGFloat = 12

    /// The ground: what the window is, behind the sidebar and the page.
    static func page(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.141, green: 0.141, blue: 0.165)
                        : Color(red: 0.945, green: 0.947, blue: 0.961)
    }

    /// The sidebar panel, a step behind the ground.
    static func sidebar(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.063, green: 0.063, blue: 0.075)
                        : Color(red: 0.796, green: 0.812, blue: 0.859)
    }

    /// The bar above a page where one still has one. Same as the ground: the
    /// window has one surface behind everything now, not two.
    static func chrome(_ scheme: ColorScheme) -> Color { page(scheme) }

    /// Everything that is not the ground sits on one of these, a step in front.
    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.204, green: 0.204, blue: 0.243) : .white
    }

    /// A step above a card: selected rows, insets, the strip behind a preview.
    static func raised(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.255, green: 0.255, blue: 0.298)
                        : Color(red: 0.949, green: 0.953, blue: 0.969)
    }

    /// The pill under the sidebar row that is open: a lift, not the accent.
    /// The accent belongs to controls; a row that is merely where you are
    /// does not need to shout it.
    static func selection(_ scheme: ColorScheme) -> Color {
        Color.primary.opacity(scheme == .dark ? 0.12 : 0.12)
    }

    static func stroke(_ scheme: ColorScheme) -> Color {
        Color.primary.opacity(scheme == .dark ? 0.07 : 0.06)
    }

    static func shadow(_ scheme: ColorScheme) -> Color {
        Color.black.opacity(scheme == .dark ? 0.24 : 0.10)
    }

    static var hairline: Color { Color.primary.opacity(0.08) }
    static var capFill: Color { Color.primary.opacity(0.07) }
    static var capStroke: Color { Color.primary.opacity(0.13) }

    /// The accent and a warmer neighbour of it, for the few places that carry a
    /// gradient. Derived from the accent rather than fixed, so choosing green
    /// does not leave a violet edge behind.
    static func gradient(_ accent: Color) -> LinearGradient {
        LinearGradient(colors: [warmer(accent), accent],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// The same colour rotated toward red. Red sits at both ends of the wheel,
    /// so which way is warmer depends on where the colour starts: violet and
    /// blue warm up by going round to magenta, green and amber by coming back
    /// to yellow. Grey stays grey — rotating the hue of an unsaturated colour
    /// changes nothing, which is the right answer for the graphite accent.
    static func warmer(_ color: Color) -> Color {
        rebuilt(color) { hue, saturation, brightness in
            let step = hue > 0.5 ? 0.14 : -0.14
            hue = (hue + step + 1).truncatingRemainder(dividingBy: 1)
            saturation = min(saturation * 1.05, 1)
            brightness = min(brightness * 1.03, 1)
        }
    }

    /// `color` taken apart into HSB, changed by `adjust`, and put back
    /// together in device RGB. Unchanged when it has no RGB form.
    static func rebuilt(_ color: Color,
                        _ adjust: (inout CGFloat, inout CGFloat, inout CGFloat) -> Void) -> Color {
        guard let base = NSColor(color).usingColorSpace(.deviceRGB) else { return color }
        var hue = base.hueComponent
        var saturation = base.saturationComponent
        var brightness = base.brightnessComponent
        adjust(&hue, &saturation, &brightness)
        return Color(nsColor: NSColor(deviceHue: hue, saturation: saturation,
                                      brightness: brightness, alpha: base.alphaComponent))
    }
}

/// A small-capitals heading: the eyebrow over a card, a section, a sidebar
/// group. Sizes vary a little by place, so both are stated at the call.
struct Eyebrow: View {
    let text: String
    var size: CGFloat = 10
    var kerning: CGFloat = 0.8

    init(_ title: LocalizedStringResource, size: CGFloat = 10, kerning: CGFloat = 0.8) {
        self.init(verbatim: String(localized: title), size: size, kerning: kerning)
    }

    /// For text already localized, like a heading a manager handed over.
    init(verbatim text: String, size: CGFloat = 10, kerning: CGFloat = 0.8) {
        self.text = text
        self.size = size
        self.kerning = kerning
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: .bold))
            .kerning(kerning)
            .muted()
    }
}

extension View {
    /// A raised surface: everything that is not the page background sits on one.
    func card() -> some View { modifier(CardSurface()) }

    /// Text that is not the subject of its row: card headings, the note under a
    /// card, a footnote.
    ///
    /// Deliberately not `.tertiary`. macOS draws that at roughly a quarter
    /// opacity, which is quiet on white and very nearly gone on the dark page —
    /// the headings and the notes were being lost against it. This is the same
    /// intent, stated as a colour that holds in both themes.
    func muted() -> some View { modifier(MutedText()) }
}

private struct MutedText: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.foregroundStyle(scheme == .dark ? Color(white: 0.68) : Color(white: 0.42))
    }
}

private struct CardSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Ink.radius, style: .continuous)
        // The shadow sits on the fill, not on the card: a shadow on the content
        // makes SwiftUI rasterize the whole subtree offscreen on every layout
        // pass, and a page of rows in cards turns into a page of bitmaps being
        // redrawn on each resize and scroll.
        return content
            .background(shape.fill(Ink.card(scheme))
                .shadow(color: Ink.shadow(scheme), radius: scheme == .dark ? 7 : 10, y: 3))
            .overlay(shape.strokeBorder(Ink.stroke(scheme)))
    }
}

/// A group heading with a rule that runs to the edge, and room for a note that
/// says something the rows themselves cannot.
struct SectionHead: View {
    let title: LocalizedStringResource
    var note: LocalizedStringResource?

    var body: some View {
        HStack(spacing: 9) {
            Eyebrow(title, kerning: 0.9)
            Rectangle().fill(Ink.hairline).frame(height: 1)
            if let note {
                Text(note).font(.caption2).muted().lineLimit(1)
            }
        }
    }
}

/// A shortcut, drawn as the keys you press. Used everywhere a row has one, so
/// the keyboard is visible on the page that owns the action instead of only on
/// a list of shortcuts somewhere else.
struct KeyCaps: View {
    let parts: [String]
    /// Whether an unbound action says so. A list of shortcuts has to — a blank
    /// cell there reads as a rendering bug — but a button that simply has no
    /// shortcut should show nothing at all.
    var showsNone = false

    var body: some View {
        HStack(spacing: 3) {
            if parts.isEmpty, showsNone {
                Text(.shortcutUnbound).font(.caption).muted()
            }
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                Text(part)
                    .font(.system(size: 11, weight: .medium))
                    .frame(minWidth: 13)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Ink.capFill))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Ink.capStroke))
            }
        }
    }
}

/// One fact about whether the app can do its job. Green states it in a word;
/// anything else says what is wrong and offers the fix.
struct StatusPill: View {
    let title: LocalizedStringResource
    let ok: Bool
    var fix: (() -> Void)?

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ok ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
                .shadow(color: (ok ? Color.green : Color.orange).opacity(0.7), radius: 3)
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            if !ok, let fix {
                Button(String(localized: .appGrant), action: fix).buttonStyle(.link).font(.system(size: 11))
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(ok ? Ink.card(scheme) : Color.orange.opacity(0.12)))
        .overlay(Capsule().strokeBorder(ok ? Ink.stroke(scheme) : Color.orange.opacity(0.35)))
    }
}

/// A button drawn as a chip: the label in the text colour on a lift off the
/// card, or in white on the accent when it is the one thing to press. The
/// system bordered button paints its label in the accent on a barely-there
/// fill, which reads as a link on the dark card and gets lost next to a title.
struct ChipButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .lineLimit(1)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .frame(height: 27)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(prominent ? AnyShapeStyle(Color.accentColor)
                                : AnyShapeStyle(Color.primary.opacity(scheme == .dark ? 0.10 : 0.07))))
            .opacity(configuration.isPressed ? 0.7 : enabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension ButtonStyle where Self == ChipButtonStyle {
    static var chip: ChipButtonStyle { ChipButtonStyle() }
    static var chipProminent: ChipButtonStyle { ChipButtonStyle(prominent: true) }
}
