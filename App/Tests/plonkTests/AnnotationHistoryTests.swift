import CoreGraphics
import Testing
@testable import plonk

struct AnnotationHistoryTests {
    private let start = CGPoint(x: 0.2, y: 0.25)
    private let end = CGPoint(x: 0.6, y: 0.75)

    @Test func oneGestureIsOneUndoableMark() {
        var history = AnnotationHistory()
        history.begin(.pen, at: start, color: 0, width: 0.01)
        history.drag(to: CGPoint(x: 0.3, y: 0.5))
        history.end(at: end)
        #expect(history.annotations.count == 1)
        #expect(history.annotations.first?.points.count == 3)
        history.undo()
        #expect(history.annotations.isEmpty)
        #expect(history.canRedo)
        history.redo()
        #expect(history.annotations.first?.points.last == end)
    }

    @Test func shapeKeepsOnlyTheStartAndFinalPoint() {
        var history = AnnotationHistory()
        history.begin(.rectangle, at: start, color: 0, width: 0.01)
        history.drag(to: CGPoint(x: 0.4, y: 0.5))
        history.end(at: end)
        #expect(history.annotations.first?.points == [start, end])
    }

    @Test func aNewMarkAfterUndoClearsRedo() {
        var history = AnnotationHistory()
        history.begin(.rectangle, at: start, color: 0, width: 0.01)
        history.end(at: end)
        history.undo()
        history.begin(.ellipse, at: start, color: 0, width: 0.01)
        #expect(history.canRedo)
        history.end(at: end)
        #expect(!history.canRedo)
        #expect(history.annotations.map(\.kind) == [.ellipse])
    }

    @Test func zeroLengthGestureDoesNotClearRedo() {
        var history = AnnotationHistory()
        history.begin(.pen, at: start, color: 0, width: 0.01)
        history.end(at: end)
        history.undo()
        history.begin(.ellipse, at: start, color: 0, width: 0.01)
        history.end(at: start)
        #expect(history.canRedo)
        #expect(history.annotations.isEmpty)
    }

    @Test func cropRebasesMarksWithoutClampingPointsOutsideTheCrop() throws {
        var history = AnnotationHistory()
        history.begin(.arrow, at: start, color: 0, width: 0.01)
        history.end(at: end)
        let crop = CGRect(x: 0.3, y: 0.25, width: 0.5, height: 0.5)
        let mark = try #require(history.rebased(to: crop).annotations.first)
        let first = try #require(mark.points.first)
        #expect(abs(first.x + 0.2) < 0.00001)
        #expect(first.y == 0)
        #expect(mark.width == 0.02)
        #expect(mark.arrowHeadWidth == 0.024)
    }

    @Test func handoffKeepsBothUndoAndRedoInCropCoordinates() {
        var history = AnnotationHistory()
        history.begin(.rectangle, at: start, color: 0, width: 0.01)
        history.end(at: end)
        history.begin(.pen, at: CGPoint(x: 0.5, y: 0.5), color: 0, width: 0.03)
        history.end(at: end)
        history.undo()

        var handoff = history.rebased(to: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
        handoff.undo()
        #expect(handoff.annotations.isEmpty)
        handoff.redo()
        handoff.redo()
        #expect(handoff.annotations.map(\.kind) == [.rectangle, .pen])
        #expect(handoff.annotations.last?.points.first == CGPoint(x: 0.5, y: 0.5))
        #expect(handoff.annotations.last?.width == 0.06)
    }
}
