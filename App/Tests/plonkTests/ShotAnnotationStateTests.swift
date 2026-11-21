import CoreGraphics
import Testing
@testable import plonk

struct ShotAnnotationStateTests {
    @Test func captureStartsWithAllConfiguredStyles() {
        let defaults = AnnotationStyles(rectangle: .init(width: 5, color: .green),
                                       ellipse: .init(width: 8, color: .blue),
                                       arrow: .init(width: 12, color: .purple),
                                       highlight: .init(width: 31, color: .orange),
                                       pen: .init(width: 42, color: .black))

        let capture = ShotAnnotationState(defaults: defaults)

        #expect(capture.styles == defaults)
    }

    @Test func toolSwitchingRecallsEachToolsTemporaryStyle() throws {
        let capture = ShotAnnotationState(defaults: .init())
        capture.tool = .rectangle
        capture.styles.rectangle = .init(width: 5, color: .green)
        capture.tool = .ellipse
        capture.styles.ellipse = .init(width: 8, color: .blue)
        capture.tool = .rectangle

        var history = AnnotationHistory()
        capture.beginMark(in: &history, at: .zero, pixelWidth: 1000)

        let mark = try #require(history.live)
        #expect(mark.colorIndex == AnnotationColor.green.index)
        #expect(mark.width == 0.005)
    }

    @Test func nextCaptureReadsDefaultsAfterTemporaryEdits() {
        var config = Config()
        config.shotAnnotationStyles.rectangle = .init(width: 7, color: .purple)
        let capture = ShotAnnotationState(defaults: config.shotAnnotationStyles)
        capture.styles.rectangle = .init(width: 5, color: .green)

        let next = ShotAnnotationState(defaults: config.shotAnnotationStyles)

        #expect(next.styles.rectangle == .init(width: 7, color: .purple))
    }

    @Test func openingEditorKeepsSelectedToolBeforeAnyMarksExist() {
        let capture = ShotAnnotationState(defaults: .init())
        capture.tool = .rectangle

        capture.enterEditor()

        #expect(capture.tool == .rectangle)
    }

    @Test func openingEditorFromMoveModeSelectsArrow() {
        let capture = ShotAnnotationState(defaults: .init())

        capture.enterEditor()

        #expect(capture.tool == .arrow)
    }

    @Test func firstEditorMarkUsesTheTemporaryStyle() throws {
        let capture = ShotAnnotationState(defaults: .init())
        capture.tool = .rectangle
        capture.styles.rectangle = .init(width: 5, color: .green)

        capture.enterEditor()
        var history = AnnotationHistory()
        capture.beginMark(in: &history, at: .zero, pixelWidth: 500)

        let mark = try #require(history.live)
        #expect(mark.colorIndex == AnnotationColor.green.index)
        #expect(mark.width * 500 == 5)
    }
}
