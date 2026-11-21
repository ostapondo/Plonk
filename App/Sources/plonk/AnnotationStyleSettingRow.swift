import SwiftUI

struct AnnotationStyleSettingRow: View {
    let kind: Annotation.Kind
    @Binding var style: AnnotationStyle
    @State private var invalidWidth = false

    var body: some View {
        SettingBlock {
            let widthField = AnnotationWidthField(kind: kind, width: $style.width, invalid: $invalidWidth)
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 12) {
                    Label { Text(kind.title) } icon: { Image(systemName: kind.symbol) }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    AnnotationPalette(selection: $style.color)
                    HStack(spacing: 4) {
                        widthField.frame(width: 48, height: 22)
                        Text(.annotationPixelUnit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if invalidWidth {
                    Text(widthField.rangeMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
