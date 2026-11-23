import SwiftUI

struct QuickShotStyleControls: View {
    let kind: Annotation.Kind
    @Binding var style: AnnotationStyle
    @Binding var widthHovered: Bool

    private static let paletteLayout = AnnotationPalette.Layout.doubleRow
    private static let gap: CGFloat = 9
    private static let leading: CGFloat = 5
    private static let trailing: CGFloat = 13
    private static let dividerWidth: CGFloat = 1

    static let size = CGSize(
        width: leading + AnnotationWidthControl.size.width + gap + dividerWidth + gap + paletteLayout.size.width + trailing,
        height: max(AnnotationWidthControl.size.height, paletteLayout.size.height) + 9
    )
    static let helpHeight: CGFloat = 38
    static let helpWidth: CGFloat = 260
    static let surface = Color(nsColor: QuickShotToolbar.surface)
    static let edge = Color(nsColor: QuickShotToolbar.edge)

    var body: some View {
        HStack(spacing: Self.gap) {
            AnnotationWidthControl(width: $style.width, range: kind.widthRange, hovering: $widthHovered)
            Rectangle().fill(Self.edge).frame(width: Self.dividerWidth, height: 18)
            AnnotationPalette(selection: $style.color, layout: Self.paletteLayout)
        }
        .padding(.leading, Self.leading)
        .padding(.trailing, Self.trailing)
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
