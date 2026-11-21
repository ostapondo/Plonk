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
                let size: CGFloat = compact ? 16 : 20
                let ring = compact ? Color(white: 0.8) : color.paint
                Button {
                    if !selected { selection = color }
                } label: {
                    Circle()
                        .fill(color.paint)
                        .overlay(Circle().strokeBorder((compact ? Color.white : .primary).opacity(0.24),
                                                       lineWidth: 0.5))
                        .padding(compact ? 2 : (selected ? 2.5 : 0))
                        .overlay {
                            if selected {
                                Circle().strokeBorder(ring, lineWidth: 1.5)
                                    .overlay(Circle().strokeBorder(.primary.opacity(compact ? 0 : 0.25),
                                                                   lineWidth: 0.5))
                            }
                        }
                        .frame(width: size, height: size)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(color.title))
                .accessibilityAddTraits(selected ? .isSelected : [])
                .help(String(localized: color.title))
            }
        }
        .fixedSize()
    }
}
