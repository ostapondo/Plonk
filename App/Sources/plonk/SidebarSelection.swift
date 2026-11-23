import SwiftUI

// The pill behind the open sidebar row. One view for the whole list, placed
// over whichever row reports itself selected, so a change of page slides and
// stretches the same piece of glass instead of fading one out and another in.

struct SidebarSelectionKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

struct SidebarSelectionPill: View {
    let anchor: Anchor<CGRect>?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.glassOn) private var glassOn

    static let radius: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            if let anchor {
                let rect = geo[anchor]
                pill
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder private var pill: some View {
        if glassOn {
            Color.clear
                .glassSurface(radius: Self.radius, style: GlassStyle(tint: Ink.selectionTint(scheme)))
        } else {
            RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
                .fill(Ink.selection(scheme))
        }
    }
}

extension View {
    /// Reports this row's bounds to the pill while it is the open one.
    func sidebarSelection(_ selected: Bool) -> some View {
        anchorPreference(key: SidebarSelectionKey.self, value: .bounds) { selected ? $0 : nil }
    }

    /// The faint lift a row gets under the pointer, the way a source list does.
    func sidebarHover(_ hovered: Bool) -> some View {
        background(RoundedRectangle(cornerRadius: SidebarSelectionPill.radius, style: .continuous)
            .fill(Color.primary.opacity(hovered ? 0.06 : 0)))
    }
}
