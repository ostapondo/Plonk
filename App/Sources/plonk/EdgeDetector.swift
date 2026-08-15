import CoreGraphics
import Foundation

// Where the thing under the pointer stops.
//
// A button, a table cell, the gap between two paragraphs: the eye sees a
// boundary there, and no API knows about any of it, because it is drawn inside
// somebody else's window. So the boundary is found the way the eye finds it, in
// the pixels: from the point, walk out in each of the four directions until one
// pixel is suddenly unlike the one before it, and that is the edge.
//
// Each step is compared with its neighbour rather than with the pixel under the
// pointer, which is the difference between measuring a thing and measuring a
// colour. Compared with the pointer, a gradient drifts far enough to stop the
// scan halfway across itself, while a panel and the panel beside it in the same
// grey read as one continuous nothing. Compared with the neighbour, a gradient
// is walked through — no single step is large — and a real border stops it even
// when it is one shade off what it borders.
//
// PowerToys' Screen Ruler works this way too, and its tolerance setting is here
// for the same reason: nothing on a modern desktop is a flat colour, so "the
// same" has to mean "near enough", and how near depends on what is being
// measured.

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

        static func mean(_ colours: [Colour]) -> Colour {
            let count = max(colours.count, 1)
            return Colour(red: colours.reduce(0) { $0 + $1.red } / count,
                          green: colours.reduce(0) { $0 + $1.green } / count,
                          blue: colours.reduce(0) { $0 + $1.blue } / count)
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
    /// How far apart two neighbouring pixels have to be, on one channel, before
    /// the boundary between them counts as an edge.
    ///
    /// Ten, measured rather than guessed: a desk of dark editor panels was
    /// probed at 4, 8, 15 and 30, and everything up to 15 agreed on the same
    /// blocks while 30 walked straight through the hairline between two panels
    /// and reported one run half again as long. Steps inside a gradient or a
    /// shadow are far smaller than this; a border, even one a shade off what it
    /// borders, is larger.
    static let defaultTolerance = 10
    static let toleranceRange = 1...80

    /// How far the pointer can travel in each direction before something
    /// changes, in the grid's own pixels: the run across meeting the run down.
    /// Nil when the point is outside the picture.
    ///
    /// These are two independent answers that happen to share a corner, not the
    /// outline of one thing, and the ruler draws them as two. On a plain
    /// rectangle they agree with its sides, which is what makes a button, a row
    /// or a gap measure the way it looks.
    static func spans(in grid: PixelGrid, at point: CGPoint, tolerance: Int) -> CGRect? {
        let x = Int(point.x.rounded(.down))
        let y = Int(point.y.rounded(.down))
        guard grid.colour(x: x, y: y) != nil else { return nil }
        let allowed = max(0, tolerance)

        let left = edge(grid, from: x, y, dx: -1, dy: 0, allowed).x
        let right = edge(grid, from: x, y, dx: 1, dy: 0, allowed).x
        let top = edge(grid, from: x, y, dx: 0, dy: -1, allowed).y
        let bottom = edge(grid, from: x, y, dx: 0, dy: 1, allowed).y

        return CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
    }

    /// The last pixel in that direction before the step to the next one is
    /// bigger than the tolerance allows.
    private static func edge(_ grid: PixelGrid, from x: Int, _ y: Int, dx: Int, dy: Int,
                             _ tolerance: Int) -> (x: Int, y: Int) {
        var last = (x: x, y: y)
        guard var previous = sample(grid, x: x, y: y, dx: dx, dy: dy) else { return last }
        var next = (x: x + dx, y: y + dy)
        while let colour = sample(grid, x: next.x, y: next.y, dx: dx, dy: dy),
              colour.difference(from: previous) <= tolerance {
            last = next
            previous = colour
            next = (x: next.x + dx, y: next.y + dy)
        }
        return last
    }

    /// A pixel averaged with the two beside it, across the scan rather than
    /// along it. A photograph, a video still or a dithered gradient is speckled
    /// enough that neighbouring pixels differ on their own, and every one of
    /// those would otherwise be an edge; three pixels of a real border still
    /// average to a border. Across rather than along, so the boundary the scan
    /// is walking towards stays exactly where it is.
    private static func sample(_ grid: PixelGrid, x: Int, y: Int,
                               dx: Int, dy: Int) -> PixelGrid.Colour? {
        guard let middle = grid.colour(x: x, y: y) else { return nil }
        // Perpendicular to the direction of travel.
        let (ox, oy) = (dy == 0 ? 0 : 1, dx == 0 ? 0 : 1)
        let neighbours = [grid.colour(x: x - ox, y: y - oy), grid.colour(x: x + ox, y: y + oy)]
        return PixelGrid.Colour.mean([middle] + neighbours.compactMap { $0 })
    }
}
