import SwiftUI

struct AnnotationWidthSlider: View {
    @Binding var width: Int
    let range: ClosedRange<Int>

    var body: some View {
        let position = Binding(
            get: { Self.position(for: width) },
            set: { width = Self.width(at: $0, in: range) }
        )
        Slider(value: position, in: Self.position(for: range.lowerBound)...Self.position(for: range.upperBound)) {
            Text(.shotEditorWidth)
        }
        .frame(width: 110)
        .accessibilityValue(Text(.annotationWidthValue(width)))
        .help(String(localized: .annotationWidthValue(width)))
    }

    // Give common small widths room to adjust while keeping the full pixel range available.
    static func position(for width: Int) -> Double {
        log(Double(width))
    }

    static func width(at position: Double, in range: ClosedRange<Int>) -> Int {
        Int(exp(position).rounded().clamped(to: Double(range.lowerBound)...Double(range.upperBound)))
    }
}
