import CoreGraphics
import Foundation

// Where the thing under the pointer stops.
//
// A button, a table cell, the gap between two paragraphs: the eye sees a
// boundary there, and no API knows about any of it, because it is drawn inside
// somebody else's window. So the boundary is found the way the eye finds it, in
// the pixels. From the point, walk out in each of the four directions until the
// colour stops matching, and the box between those four stops is what was
// under the cursor.
//
// PowerToys' Screen Ruler works this way too, and its tolerance setting is here
// for the same reason: nothing on a modern desktop is one flat colour —
// gradients, shadows, subpixel text — so "the same colour" has to mean "near
// enough", and how near is a matter of taste and of what is being measured.

/// A picture in memory: 8 bits a channel, origin top-left, y downward, which is
/// the space `CGImage` and every capture in this app already speak.
struct PixelGrid {
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let bytesPerPixel: Int
    let data: Data

    struct Colour: Equatable {
        let red: Int
        let green: Int
        let blue: Int

        /// The largest single-channel difference. Per channel rather than a
        /// distance, so a change in one colour only is as loud as a change in
        /// all three: green text on a grey panel has to read as an edge.
        func difference(from other: Colour) -> Int {
            max(abs(red - other.red), max(abs(green - other.green), abs(blue - other.blue)))
        }
    }

    /// Nil outside the picture, which is what ends every scan at the last
    /// pixel rather than off the end of the buffer.
    func colour(x: Int, y: Int) -> Colour? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        let offset = y * bytesPerRow + x * bytesPerPixel
        guard offset + 2 < data.count else { return nil }
        return Colour(red: Int(data[offset]), green: Int(data[offset + 1]), blue: Int(data[offset + 2]))
    }
}

extension PixelGrid {
    /// Redrawn into a buffer this code owns, because a capture may arrive in
    /// any format the display happens to use — 16 bits a channel on an HDR
    /// screen, or a colour space nothing here wants to reason about.
    init?(image: CGImage) {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        let bytesPerRow = width * 4
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let context = CGContext(
            data: &buffer, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        self.init(width: width, height: height, bytesPerRow: bytesPerRow,
                  bytesPerPixel: 4, data: Data(buffer))
    }
}

enum EdgeDetector {
    /// How far apart two pixels have to be, on one channel, before the boundary
    /// between them counts as an edge. Low enough that a border one shade off
    /// its panel still stops a scan, high enough that a gradient does not.
    static let defaultTolerance = 30
    static let toleranceRange = 1...120

    /// The box of near-enough-the-same colour around `point`, in the grid's own
    /// pixels. Nil when the point is outside the picture.
    ///
    /// The box is the run through the point across, meeting the run through it
    /// down: it is what the cursor is inside, not the shape of the whole thing
    /// it belongs to. On a rectangle those are the same answer, which is why
    /// the rectangles a desktop is made of come out right.
    static func bounds(in grid: PixelGrid, at point: CGPoint, tolerance: Int) -> CGRect? {
        let x = Int(point.x.rounded(.down))
        let y = Int(point.y.rounded(.down))
        guard let reference = grid.colour(x: x, y: y) else { return nil }
        let allowed = max(0, tolerance)

        let left = edge(grid, from: x, y, dx: -1, dy: 0, reference, allowed).x
        let right = edge(grid, from: x, y, dx: 1, dy: 0, reference, allowed).x
        let top = edge(grid, from: x, y, dx: 0, dy: -1, reference, allowed).y
        let bottom = edge(grid, from: x, y, dx: 0, dy: 1, reference, allowed).y

        return CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
    }

    /// The last pixel in that direction still within tolerance of `reference`.
    private static func edge(_ grid: PixelGrid, from x: Int, _ y: Int, dx: Int, dy: Int,
                             _ reference: PixelGrid.Colour, _ tolerance: Int) -> (x: Int, y: Int) {
        var last = (x: x, y: y)
        var next = (x: x + dx, y: y + dy)
        while let colour = grid.colour(x: next.x, y: next.y),
              colour.difference(from: reference) <= tolerance {
            last = next
            next = (x: next.x + dx, y: next.y + dy)
        }
        return last
    }
}
