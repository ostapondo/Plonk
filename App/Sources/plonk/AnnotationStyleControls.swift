import SwiftUI

struct AnnotationStyleControls: View {
    let kind: Annotation.Kind
    @Binding var width: Int
    @Binding var color: AnnotationColor
    @Binding var widthHovered: Bool

    static let size = CGSize(width: 177, height: 46)
    static let helpHeight: CGFloat = 38
    static let helpWidth: CGFloat = 260
    static let surface = Color(red: 48 / 255, green: 51 / 255, blue: 54 / 255)
    static let edge = Color.white.opacity(0.18)

    var body: some View {
        HStack(spacing: 7) {
            AnnotationWidthControl(width: $width, range: kind.widthRange, hovering: $widthHovered)
            Rectangle().fill(Self.edge).frame(width: 1, height: 18)
            AnnotationPalette(selection: $color, compact: true)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Self.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Self.edge, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 5, y: 3)
    }

    static var widthHelp: some View {
        Text(.annotationWidthDragHelp)
            .font(.system(size: 11))
            .foregroundStyle(Color(white: 0.92))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(surface, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(edge, lineWidth: 1))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
