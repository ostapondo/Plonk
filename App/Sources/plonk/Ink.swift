import AppKit
import SwiftUI

// The look every page is built from: three surfaces, one hairline, one radius.
//
// Stated as real colours rather than opacities over whatever macOS supplies.
// Tinted greys layered on the window background gave two panes that were nearly
// the same value, and the whole window read flat; a page that is definitely
// darker than its cards is what makes the cards look like cards.
//
// Both themes are spelled out because the app has a theme of its own now: a
// window forced to light while the system is dark cannot ask NSColor what grey
// to use and get an answer that suits the window it is actually in.

enum Ink {
    static let radius: CGFloat = 11

    /// Behind the pages. The sidebar keeps the system material, and this sits
    /// beside it, a shade further back.
    static func page(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.047, green: 0.051, blue: 0.067)
                        : Color(red: 0.957, green: 0.961, blue: 0.973)
    }

    /// The bar above the page: a shade in front of it, so the page reads as
    /// something the window contains rather than as the window itself.
    static func chrome(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.067, green: 0.075, blue: 0.098) : .white
    }

    /// Everything that is not the page background sits on one of these.
    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.086, green: 0.098, blue: 0.129) : .white
    }

    /// A step above a card: selected rows, insets, the strip behind a preview.
    static func raised(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.110, green: 0.125, blue: 0.161)
                        : Color(red: 0.949, green: 0.953, blue: 0.969)
    }

    static func stroke(_ scheme: ColorScheme) -> Color {
        Color.primary.opacity(scheme == .dark ? 0.10 : 0.09)
    }

    static func shadow(_ scheme: ColorScheme) -> Color {
        Color.black.opacity(scheme == .dark ? 0.32 : 0.06)
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
        guard let base = NSColor(color).usingColorSpace(.deviceRGB) else { return color }
        let step = base.hueComponent > 0.5 ? 0.14 : -0.14
        let hue = (base.hueComponent + step + 1).truncatingRemainder(dividingBy: 1)
        return Color(nsColor: NSColor(deviceHue: hue,
                                      saturation: min(base.saturationComponent * 1.05, 1),
                                      brightness: min(base.brightnessComponent * 1.03, 1),
                                      alpha: base.alphaComponent))
    }
}

extension View {
    /// A raised surface: everything that is not the page background sits on one.
    func card() -> some View { modifier(CardSurface()) }
}

private struct CardSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Ink.radius, style: .continuous)
        return content
            .background(shape.fill(Ink.card(scheme)))
            .overlay(shape.strokeBorder(Ink.stroke(scheme)))
            .shadow(color: Ink.shadow(scheme), radius: 7, y: 2)
    }
}

/// A group heading with a rule that runs to the edge, and room for a note that
/// says something the rows themselves cannot.
struct SectionHead: View {
    let title: LocalizedStringResource
    var note: LocalizedStringResource?

    var body: some View {
        HStack(spacing: 9) {
            Text(String(localized: title).uppercased())
                .font(.system(size: 10, weight: .bold))
                .kerning(0.9)
                .foregroundStyle(.tertiary)
            Rectangle().fill(Ink.hairline).frame(height: 1)
            if let note {
                Text(note).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
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
                Text(.shortcutUnbound).font(.caption).foregroundStyle(.tertiary)
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
