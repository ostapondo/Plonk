import AppKit
import Testing
@testable import plonk

struct AnnotationHistoryTests {
    @Test func handoffPreservesThePositionAndSizeOfMarksOutsideTheCrop() throws {
        var history = AnnotationHistory()
        history.begin(.arrow, at: CGPoint(x: 0.125, y: 0.125), color: 0, width: 0.002)
        history.drag(to: CGPoint(x: 0.5, y: 0.5))
        history.end()
        let moved = history.rebased(to: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.25))
        let arrow = try #require(moved.annotations.first)
        #expect(arrow.points == [CGPoint(x: -0.25, y: -0.5), CGPoint(x: 0.5, y: 1)])
        #expect(arrow.width == 0.004)
        #expect(arrow.arrowHead == 0.024)
    }

    @Test func textAndRedoSurviveHandoff() throws {
        var history = AnnotationHistory()
        history.append(Annotation(kind: .text, points: [CGPoint(x: 0.5, y: 0.5)], colorIndex: 2,
                                  width: 0.025, text: "First line\n第二行"))
        history.undo()
        var moved = history.rebased(to: CGRect(x: 0.25, y: 0, width: 0.5, height: 1))
        moved.redo()
        let text = try #require(moved.annotations.first)
        #expect(text.points == [CGPoint(x: 0.5, y: 0.5)])
        #expect(text.width == 0.05)
        #expect(text.text == "First line\n第二行")
        moved.undo()
        #expect(moved.annotations.isEmpty)
    }
}
