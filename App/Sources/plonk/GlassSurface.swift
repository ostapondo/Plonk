import SwiftUI

/// Glass belongs to navigation and primary controls. Content cards use the
/// quieter material in Ink so their text stays readable while scrolling.
struct GlassSurface: ViewModifier {
    var radius: CGFloat
    @Environment(\.colorScheme) private var scheme

    @ViewBuilder func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: shape)
        } else {
            materialSurface(content, shape: shape)
        }
        #else
        materialSurface(content, shape: shape)
        #endif
    }

    private func materialSurface(_ content: Content, shape: RoundedRectangle) -> some View {
        content
            .background(.regularMaterial, in: shape)
            .overlay(shape.strokeBorder(Ink.glassEdge(scheme)))
    }
}

extension View {
    func glassSurface(radius: CGFloat) -> some View {
        modifier(GlassSurface(radius: radius))
    }
}
