import SwiftUI

struct AnnotationPalette: View {
    enum Layout: Int, CaseIterable {
        case singleRow = 8
        case doubleRow = 4

        var rows: [ArraySlice<AnnotationColor>] {
            let colors = AnnotationColor.allCases
            return stride(from: 0, to: colors.count, by: rawValue).map { start in
                colors[start..<min(start + rawValue, colors.count)]
            }
        }

        var size: CGSize {
            let columns = CGFloat(rawValue)
            let rowCount = CGFloat(rows.count)
            return CGSize(width: columns * AnnotationPalette.diameter + (columns - 1) * AnnotationPalette.columnGap,
                          height: rowCount * AnnotationPalette.diameter + (rowCount - 1) * AnnotationPalette.rowGap)
        }
    }

    @Binding var selection: AnnotationColor
    var layout: Layout = .singleRow

    private static let diameter: CGFloat = 17
    private static let columnGap: CGFloat = 5
    private static let rowGap: CGFloat = 3

    var body: some View {
        VStack(spacing: Self.rowGap) {
            ForEach(layout.rows, id: \.startIndex) { colors in
                row(colors)
            }
        }
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(.annotationColors))
    }

    private func row(_ colors: ArraySlice<AnnotationColor>) -> some View {
        HStack(spacing: Self.columnGap) {
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
    }

    private func swatch(_ color: AnnotationColor, selected: Bool) -> some View {
        let inset: CGFloat = selected ? 2.5 : 0
        var strokes = [AnnotationCircle.Stroke(color: .primary.opacity(0.24), width: 0.5, inset: inset)]
        if selected {
            strokes.append(.init(color: .white.opacity(0.9), width: 1.5))
            strokes.append(.init(color: .black.opacity(0.45), width: 0.5))
        }
        return AnnotationCircle(fill: color.paint, fillInset: inset, strokes: strokes)
            .frame(width: Self.diameter, height: Self.diameter)
            .contentShape(Circle())
    }
}
