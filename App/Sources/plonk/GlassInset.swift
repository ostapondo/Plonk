import SwiftUI

// What sits inside a card. The card is already glass, and glass on glass
// reads as fog, so anything in it that is only grouping is a faint fill and
// only the controls get glass of their own.

extension Ink {
    /// A row tile or an inset inside a card. Concentric with `radius` at the
    /// padding a card gives its content.
    static let insetRadius: CGFloat = 12
    /// A floating panel over other windows: the palettes.
    static let floatRadius: CGFloat = 26
}

private struct InsetSurface: ViewModifier {
    var radius: CGFloat
    var selected: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.glassOn) private var glassOn

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content.background(shape.fill(fill))
    }

    private var fill: Color {
        if selected { return Color.accentColor.opacity(scheme == .dark ? 0.22 : 0.14) }
        // On glass the card has no colour of its own, so a raised colour would
        // be an opaque slab; a tint of the text colour lets the glass through.
        if glassOn { return Color.primary.opacity(scheme == .dark ? 0.07 : 0.045) }
        return Ink.raised(scheme)
    }
}

private struct FloatingPanelSurface: ViewModifier {
    @Environment(\.glassOn) private var glassOn

    @ViewBuilder func body(content: Content) -> some View {
        if glassOn {
            let shape = RoundedRectangle(cornerRadius: Ink.floatRadius, style: .continuous)
            // Clipped as well: glass draws behind the content but does not
            // stop a scrolled row from running out past the corners.
            content.clipShape(shape).glassSurface(radius: Ink.floatRadius)
        } else {
            let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
            content
                .background(VisualEffect(material: .popover))
                .clipShape(shape)
                .overlay(shape.strokeBorder(Ink.capStroke))
        }
    }
}

extension View {
    /// A static inset inside a card: a row tile, a list, a preview strip.
    func insetSurface(radius: CGFloat = Ink.insetRadius, selected: Bool = false) -> some View {
        modifier(InsetSurface(radius: radius, selected: selected))
    }

    /// The row a list's arrow keys are on: a rounded wash of the accent,
    /// inset from the panel edge, instead of a full-width bar.
    func rowHighlight(_ on: Bool, radius: CGFloat = 10) -> some View {
        background(RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(on ? Color.accentColor.opacity(0.16) : Color.clear))
    }

    /// A capsule of glass on macOS 26 and nothing before it, for a view that
    /// already draws its own surface on older systems.
    func nativeGlassCapsule(_ style: GlassStyle) -> some View {
        modifier(NativeGlassCapsule(style: style))
    }

    /// A card that is itself a button, such as a quick-action tile: glass that
    /// answers the pointer on macOS 26, an ordinary card before it.
    func cardControl() -> some View { modifier(CardControl()) }

    /// The whole surface of a floating panel such as the command palette.
    func floatingPanel() -> some View { modifier(FloatingPanelSurface()) }
}

private struct NativeGlassCapsule: ViewModifier {
    var style: GlassStyle
    @Environment(\.glassOn) private var glassOn

    @ViewBuilder func body(content: Content) -> some View {
        if glassOn { content.glassCapsule(style) } else { content }
    }
}

private struct CardControl: ViewModifier {
    @Environment(\.glassOn) private var glassOn

    @ViewBuilder func body(content: Content) -> some View {
        if glassOn {
            content.glassSurface(radius: Ink.radius, style: .control)
        } else {
            content.card()
        }
    }
}
