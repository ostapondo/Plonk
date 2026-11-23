import Testing
@testable import plonk

@MainActor
struct AnnotationWidthSliderTests {
    @Test(arguments: Annotation.Kind.styleOrder)
    func sliderPositionsRoundTripSourcePixelWidths(_ tool: Annotation.Kind) {
        let range = tool.widthRange
        for width in [range.lowerBound, 20, 100, 102, range.upperBound] {
            let position = AnnotationWidthSlider.position(for: width)
            #expect(AnnotationWidthSlider.width(at: position, in: range) == width)
        }
    }
}
