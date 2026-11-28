import CoreGraphics
import Testing
@testable import plonk

struct AnnotationConstraintTests {
    private let imageSize = CGSize(width: 800, height: 400)
    private let start = CGPoint(x: 0.5, y: 0.5)

    @Test(arguments: [Annotation.Kind.rectangle, .ellipse])
    func maximumImagePixelDeltaAppliesInAllDirections(kind: Annotation.Kind) {
        let endpoints: [(pointer: CGPoint, corner: CGPoint)] = [
            (.init(x: 0.75, y: 0.5), .init(x: 0.75, y: 1)),
            (.init(x: 0.25, y: 0.5), .init(x: 0.25, y: 1)),
            (.init(x: 0.5, y: 0.75), .init(x: 0.625, y: 0.75)),
            (.init(x: 0.5, y: 0.25), .init(x: 0.625, y: 0.25)),
            (.init(x: 0.625, y: 0.875), .init(x: 0.6875, y: 0.875)),
            (.init(x: 0.375, y: 0.875), .init(x: 0.3125, y: 0.875)),
            (.init(x: 0.625, y: 0.125), .init(x: 0.6875, y: 0.125)),
            (.init(x: 0.375, y: 0.125), .init(x: 0.3125, y: 0.125))
        ]
        for (pointer, corner) in endpoints {
            var history = AnnotationHistory()
            history.begin(kind, at: start, color: 0, width: 0.01)
            history.drag(to: pointer, squareIn: imageSize)
            #expect(history.live?.points == [start, corner])
        }
    }

    @Test func togglingUsesTheLastRawPointerAndCommitsOneUndoableMark() throws {
        let pointer = CGPoint(x: 0.75, y: 0.625)
        var history = AnnotationHistory()
        history.begin(.rectangle, at: start, color: 2, width: 0.01)
        history.drag(to: pointer)

        history.updateSquareConstraint(in: imageSize)
        #expect(history.live?.points == [start, CGPoint(x: 0.75, y: 1)])
        history.updateSquareConstraint(in: nil)
        #expect(history.live?.points == [start, pointer])
        history.updateSquareConstraint(in: imageSize)

        let preview = try #require(history.live)
        history.end(at: pointer, squareIn: imageSize)
        history.updateSquareConstraint(in: nil)
        #expect(history.annotations == [preview])
        history.undo()
        #expect(!history.canUndo)
        history.redo()
        #expect(history.annotations == [preview])
    }

    @Test func returningToTheAnchorLeavesTheRedoStackIntact() {
        var history = AnnotationHistory()
        history.begin(.ellipse, at: start, color: 0, width: 0.01)
        history.end(at: CGPoint(x: 0.75, y: 0.75), squareIn: imageSize)
        history.undo()

        history.begin(.ellipse, at: start, color: 0, width: 0.01)
        history.drag(to: CGPoint(x: 0.75, y: 0.75), squareIn: imageSize)
        history.drag(to: start, squareIn: imageSize)
        history.updateSquareConstraint(in: nil)
        #expect(history.live?.points == [start])
        history.end(at: start, squareIn: imageSize)
        #expect(history.live == nil)
        #expect(history.annotations.isEmpty)
        #expect(history.canRedo)
    }

    @Test(arguments: [Annotation.Kind.arrow, .pen, .highlight])
    func otherToolsKeepTheirOriginalPoints(kind: Annotation.Kind) {
        let middle = CGPoint(x: 0.75, y: 0.75)
        let end = CGPoint(x: 0.625, y: 0.75)
        var history = AnnotationHistory()
        history.begin(kind, at: start, color: 0, width: 0.01)
        history.drag(to: middle, squareIn: imageSize)
        history.updateSquareConstraint(in: nil)
        #expect(history.live?.points == [start, middle])
        history.end(at: end, squareIn: imageSize)
        #expect(history.annotations.first?.points == (kind == .arrow ? [start, end] : [start, middle, end]))
    }

    @Test func rebasingKeepsTheSquareAndItsStyleBeyondTheCropBoundary() throws {
        let start = CGPoint(x: 0.625, y: 0.5)
        var history = AnnotationHistory()
        history.begin(.rectangle, at: start, color: 2, width: 0.01)
        history.end(at: CGPoint(x: 0.6875, y: 0.875), squareIn: imageSize)

        let crop = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let mark = try #require(history.rebased(to: crop).annotations.first)
        #expect(mark.boundingRect(in: CGSize(width: 400, height: 200)) ==
                CGRect(x: 300, y: 100, width: 150, height: 150))
        #expect(mark.boundingRect(in: CGSize(width: 200, height: 100)) ==
                CGRect(x: 150, y: 50, width: 75, height: 75))
        #expect(mark.colorIndex == 2)
        #expect(mark.width == 0.02)
    }
}
