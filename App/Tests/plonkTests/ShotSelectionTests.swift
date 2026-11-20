import CoreGraphics
import Testing
@testable import plonk

struct ShotSelectionTests {
    private let geometry = ShotSelection(pixels: CGSize(width: 600, height: 400),
                                         view: CGSize(width: 300, height: 200))

    @Test func reverseDragCreatesAnIntegralPixelRect() {
        let rect = geometry.selection(from: CGPoint(x: 110.3, y: 90.2),
                                      to: CGPoint(x: 10.1, y: 20.4))
        #expect(rect == CGRect(x: 20, y: 41, width: 201, height: 139))
    }

    @Test func creationStaysOnTheOriginatingDisplay() {
        let rect = geometry.selection(from: CGPoint(x: 30, y: 40), to: CGPoint(x: 500, y: -20))
        #expect(rect == CGRect(x: 60, y: 0, width: 540, height: 80))
    }

    @Test func clickDoesNotCreateAnEmptySelection() {
        #expect(geometry.selection(from: .zero, to: CGPoint(x: 0, y: 9)) == nil)
    }

    @Test func pixelRectProjectsBackToViewPoints() {
        #expect(geometry.viewRect(CGRect(x: 3, y: 5, width: 101, height: 81))
                == CGRect(x: 1.5, y: 2.5, width: 50.5, height: 40.5))
    }

    @Test func movingClampsWithoutChangingSize() {
        let rect = CGRect(x: 160, y: 100, width: 200, height: 160)
        #expect(geometry.move(rect, by: CGPoint(x: -200, y: 200))
                == CGRect(x: 0, y: 240, width: 200, height: 160))
    }

    @Test func resizingFromACornerKeepsTheOppositeCornerFixed() {
        let rect = CGRect(x: 60, y: 80, width: 200, height: 100)
        #expect(geometry.resize(rect, handle: CGPoint(x: -1, y: -1), by: CGPoint(x: -90, y: 150))
                == CGRect(x: 0, y: 179, width: 260, height: 1))
    }

    @Test func resizingFromAnEdgeOnlyChangesOneDimension() {
        let rect = CGRect(x: 60, y: 80, width: 200, height: 100)
        #expect(geometry.resize(rect, handle: CGPoint(x: 1, y: 0), by: CGPoint(x: 500, y: 150))
                == CGRect(x: 60, y: 80, width: 540, height: 100))
    }

    @Test func visibleCornerHandleHasPriorityOverTheEdge() {
        let rect = CGRect(x: 80, y: 80, width: 320, height: 180)
        #expect(geometry.handle(at: CGPoint(x: 55, y: 42), of: rect) == CGPoint(x: -1, y: -1))
    }

    @Test func centerOfEdgeProvidesOneAxisOfResize() {
        let rect = CGRect(x: 80, y: 80, width: 320, height: 180)
        #expect(geometry.handle(at: CGPoint(x: 120, y: 38), of: rect) == CGPoint(x: 0, y: -1))
    }

    @Test func pointsInTheInteriorAreAvailableForMoveOrMarkup() {
        let rect = CGRect(x: 80, y: 80, width: 320, height: 180)
        #expect(geometry.handle(at: CGPoint(x: 120, y: 85), of: rect) == .zero)
    }
}
