import SwiftUI

// The mark: a cube seen from above, white top, rose left face, blue right,
// drawn with a black outline and flat fills.
//
// It is the only hard-edged thing in the whole design — everything else is soft
// — and the two faces are zones 1 and 3, the pair that stays furthest apart on
// every kind of vision. The same drawing is on the site, in the README and on
// the icon, so this is a shape rather than an image: it has to be crisp at
// 16 points in a sidebar and at 512 in the Dock.
//
// Coordinates are the design's own 100 x 112 grid, so the geometry here and the
// SVG on the site are literally the same numbers.

struct PlonkCube: View {
    /// Outline width in grid units, scaled with everything else.
    private static let stroke: CGFloat = 2.6

    private static let top = [CGPoint(x: 12, y: 34), CGPoint(x: 50, y: 12),
                              CGPoint(x: 88, y: 34), CGPoint(x: 50, y: 56)]
    private static let left = [CGPoint(x: 12, y: 34), CGPoint(x: 50, y: 56),
                               CGPoint(x: 50, y: 100), CGPoint(x: 12, y: 78)]
    private static let right = [CGPoint(x: 88, y: 34), CGPoint(x: 50, y: 56),
                                CGPoint(x: 50, y: 100), CGPoint(x: 88, y: 78)]

    var body: some View {
        GeometryReader { geo in
            let unit = min(geo.size.width / 100, geo.size.height / 112)
            ZStack {
                face(Self.top, unit: unit).fill(Color(red: 1, green: 0.992, blue: 0.976))
                face(Self.left, unit: unit).fill(Ink.zone(0))
                face(Self.right, unit: unit).fill(Ink.zone(2))
                outline(unit: unit)
                    .stroke(Color(red: 0.071, green: 0.063, blue: 0.11),
                            style: StrokeStyle(lineWidth: Self.stroke * unit,
                                               lineCap: .round, lineJoin: .round))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(100.0 / 112, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func face(_ points: [CGPoint], unit: CGFloat) -> Path {
        Path { path in
            path.addLines(points.map { CGPoint(x: $0.x * unit, y: $0.y * unit) })
            path.closeSubpath()
        }
    }

    /// The silhouette, then the two edges that turn a hexagon into a cube.
    private func outline(unit: CGFloat) -> Path {
        Path { path in
            let p = { (x: CGFloat, y: CGFloat) in CGPoint(x: x * unit, y: y * unit) }
            path.addLines([p(12, 34), p(50, 12), p(88, 34), p(88, 78), p(50, 100), p(12, 78)])
            path.closeSubpath()
            path.move(to: p(12, 34))
            path.addLine(to: p(50, 56))
            path.addLine(to: p(88, 34))
            path.move(to: p(50, 56))
            path.addLine(to: p(50, 100))
        }
    }
}
