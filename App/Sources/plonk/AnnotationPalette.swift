import SwiftUI

struct AnnotationPalette: View {
    @Binding var selection: AnnotationColor
    var compact = false

    var body: some View {
        VStack(spacing: 3) {
            if compact {
                row(AnnotationColor.allCases.prefix(4))
                row(AnnotationColor.allCases.dropFirst(4))
            } else {
                row(AnnotationColor.allCases[...])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(.annotationColors))
    }

    private func row(_ colors: ArraySlice<AnnotationColor>) -> some View {
        HStack(spacing: compact ? 4 : 3) {
            ForEach(colors, id: \.self) { color in
                let selected = color == selection
                Button {
                    if !selected { selection = color }
                } label: {
                    swatch(color, selected: selected)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(color.title))
                .accessibilityAddTraits(selected ? .isSelected : [])
                .help(String(localized: color.title))
            }
        }
        .fixedSize()
    }

    private func swatch(_ color: AnnotationColor, selected: Bool) -> some View {
        let size: CGFloat = compact ? 16 : 20
        let inset: CGFloat = compact ? 2 : (selected ? 2.5 : 0)
        let rim = (compact ? Color.white : .primary).opacity(0.24)
        var strokes = [AnnotationCircle.Stroke(color: rim, width: 0.5, inset: inset)]
        if selected {
            let ring = compact ? Color(white: 0.8) : color.paint
            strokes.append(.init(color: ring, width: 1.5))
            if !compact { strokes.append(.init(color: .primary.opacity(0.25), width: 0.5)) }
        }
        return AnnotationCircle(fill: color.paint, fillInset: inset, strokes: strokes)
            .frame(width: size, height: size)
            .contentShape(Circle())
    }
}
