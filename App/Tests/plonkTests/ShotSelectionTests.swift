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

    @Test func typedHeightGrowsUpFromTheBottomLeft() {
        let rect = CGRect(x: 100, y: 150, width: 200, height: 100)
        #expect(geometry.resize(rect, dimension: 175, horizontal: false, ratio: nil)
                == CGRect(x: 100, y: 75, width: 200, height: 175))
    }

    @Test func typedWidthAtTheEdgeMovesTheRectBackOntoTheDisplay() {
        let rect = CGRect(x: 450, y: 150, width: 80, height: 100)
        #expect(geometry.resize(rect, dimension: 200, horizontal: true, ratio: nil)
                == CGRect(x: 400, y: 150, width: 200, height: 100))
    }

    @Test func lockedWidthKeepsTheRatio() {
        let geometry = ShotSelection(pixels: CGSize(width: 1600, height: 1000), view: .zero)
        let rect = CGRect(x: 100, y: 450, width: 400, height: 300)
        #expect(geometry.resize(rect, dimension: 800, horizontal: true, ratio: 4.0 / 3)
                == CGRect(x: 100, y: 150, width: 800, height: 600))
    }

    @Test func oversizedLockedInputFitsBothDimensions() {
        let geometry = ShotSelection(pixels: CGSize(width: 1600, height: 1000), view: .zero)
        let rect = CGRect(x: 800, y: 200, width: 300, height: 300)
        #expect(geometry.resize(rect, dimension: 2000, horizontal: true, ratio: 1)
                == CGRect(x: 600, y: 0, width: 1000, height: 1000))
    }

    @Test func oversizedUnlockedInputOnlyClampsTheEditedAxis() {
        let rect = CGRect(x: 100, y: 100, width: 200, height: 150)
        #expect(geometry.resize(rect, dimension: 2000, horizontal: true, ratio: nil)
                == CGRect(x: 0, y: 100, width: 600, height: 150))
    }

    @Test func draggingALockedEdgeMaintainsTheRatio() {
        let rect = CGRect(x: 60, y: 80, width: 200, height: 100)
        #expect(geometry.resize(rect, handle: CGPoint(x: 1, y: 0), by: CGPoint(x: 100, y: 0), ratio: 2)
                == CGRect(x: 60, y: 80, width: 300, height: 150))
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
