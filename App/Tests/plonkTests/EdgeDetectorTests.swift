import CoreGraphics
import Foundation
import Testing
@testable import plonk

// The ruler's one piece of real logic: given pixels, where does the thing under
// the pointer stop. Grids are built by hand here, so none of this needs a
// screen, a capture or the Screen Recording permission.

/// A grid of `width` × `height` filled with `background`, with `boxes` painted
/// on top. Colours are grey levels, which is all these tests need.
private func grid(_ width: Int, _ height: Int, background: UInt8,
                  boxes: [(rect: (x: Int, y: Int, w: Int, h: Int), grey: UInt8)] = []) -> PixelGrid {
    var bytes = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            var grey = background
            for box in boxes where x >= box.rect.x && x < box.rect.x + box.rect.w
                && y >= box.rect.y && y < box.rect.y + box.rect.h {
                grey = box.grey
            }
            let offset = (y * width + x) * 4
            bytes[offset] = grey
            bytes[offset + 1] = grey
            bytes[offset + 2] = grey
        }
    }
    return PixelGrid(width: width, height: height, bytesPerRow: width * 4,
                     bytesPerPixel: 4, data: Data(bytes))
}

struct EdgeDetectorTests {

    @Test func aBoxIsMeasuredFromAnyPointInsideIt() {
        let picture = grid(40, 30, background: 255, boxes: [((x: 10, y: 6, w: 12, h: 8), 0)])
        for point in [CGPoint(x: 11, y: 7), CGPoint(x: 16, y: 10), CGPoint(x: 21, y: 13)] {
            let found = EdgeDetector.bounds(in: picture, at: point, tolerance: 30)
            #expect(found == CGRect(x: 10, y: 6, width: 12, height: 8), "from \(point)")
        }
    }

    /// The background is not one box: the scan out of it stops where the box
    /// begins, which is what makes the gap beside a thing measurable.
    @Test func theRunBesideABoxStopsAtIt() {
        let picture = grid(40, 30, background: 255, boxes: [((x: 10, y: 6, w: 12, h: 8), 0)])
        let found = EdgeDetector.bounds(in: picture, at: CGPoint(x: 4, y: 10), tolerance: 30)
        #expect(found?.minX == 0)
        #expect(found?.maxX == 10)
    }

    @Test func aBoxTouchingTheEdgeOfTheScreenIsStillMeasured() {
        let picture = grid(20, 20, background: 255, boxes: [((x: 0, y: 0, w: 5, h: 4), 0)])
        let found = EdgeDetector.bounds(in: picture, at: CGPoint(x: 2, y: 1), tolerance: 30)
        #expect(found == CGRect(x: 0, y: 0, width: 5, height: 4))
    }

    /// Tolerance is the whole reason the setting exists: a shade of difference
    /// is an edge to one person and a gradient to another.
    @Test func toleranceDecidesWhetherAFaintBorderCounts() {
        let picture = grid(30, 10, background: 200, boxes: [((x: 12, y: 0, w: 2, h: 10), 180)])
        let strict = EdgeDetector.bounds(in: picture, at: CGPoint(x: 4, y: 5), tolerance: 5)
        let loose = EdgeDetector.bounds(in: picture, at: CGPoint(x: 4, y: 5), tolerance: 40)
        #expect(strict?.maxX == 12)
        #expect(loose?.maxX == 30)
    }

    @Test func aPointOutsideThePictureMeasuresNothing() {
        let picture = grid(10, 10, background: 255)
        #expect(EdgeDetector.bounds(in: picture, at: CGPoint(x: 10, y: 5), tolerance: 30) == nil)
        #expect(EdgeDetector.bounds(in: picture, at: CGPoint(x: -1, y: 5), tolerance: 30) == nil)
    }

    /// A difference on one channel is as loud as one on all three: green text
    /// on a grey panel has to read as an edge.
    @Test func oneChannelIsEnoughToBeAnEdge() {
        let grey = PixelGrid.Colour(red: 128, green: 128, blue: 128)
        let green = PixelGrid.Colour(red: 128, green: 200, blue: 128)
        #expect(grey.difference(from: green) == 72)
    }
}
