import SwiftUI

// Annotations are stored in unit coordinates of the image (0..1, origin
// top-left) rather than view points. The editor canvas and the export render
// at completely different sizes, and only unit coordinates survive both.
// Stroke width follows the same rule: a fraction of the canvas width.

struct Annotation: Identifiable, Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case pen
        case arrow
        case rectangle
        case ellipse
        case highlight

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .pen: return "scribble"
            case .arrow: return "arrow.up.right"
            case .rectangle: return "rectangle"
            case .ellipse: return "circle"
            case .highlight: return "highlighter"
            }
        }

        var title: String {
            switch self {
            case .pen: return String(localized: .toolPen)
            case .arrow: return String(localized: .toolArrow)
            case .rectangle: return String(localized: .toolRectangle)
            case .ellipse: return String(localized: .toolEllipse)
            case .highlight: return String(localized: .toolHighlight)
            }
        }

        var tracksEveryPoint: Bool { self == .pen || self == .highlight }
    }

    let id = UUID()
    var kind: Kind
    /// Pen and highlight keep every sampled point; the rest keep [start, end].
    var points: [CGPoint]
    var colorIndex: Int
    var width: Double

    static let palette: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .black, .white]
    static let colorNames = ["red", "orange", "yellow", "green", "blue", "purple", "black", "white"]

    var color: Color { Self.palette[colorIndex.clamped(to: 0...(Self.palette.count - 1))] }

    func boundingRect(in size: CGSize) -> CGRect {
        guard let first = points.first else { return .zero }
        let last = points.last ?? first
        let a = CGPoint(x: first.x * size.width, y: first.y * size.height)
        let b = CGPoint(x: last.x * size.width, y: last.y * size.height)
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }
}

extension Annotation {
    /// Parses a mark sent over the API. Points are 0..1 of the image, origin
    /// top-left, which is the space annotations already live in.
    init?(dict: [String: Any]) {
        guard let rawKind = (dict["kind"] as? String)?.lowercased(),
              let kind = Kind(rawValue: rawKind),
              let rawPoints = dict["points"] as? [[String: Any]] else { return nil }

        let points = rawPoints.compactMap { point -> CGPoint? in
            guard let x = (point["x"] as? NSNumber)?.doubleValue,
                  let y = (point["y"] as? NSNumber)?.doubleValue else { return nil }
            return CGPoint(x: x.clamped(to: 0...1), y: y.clamped(to: 0...1))
        }
        guard points.count == rawPoints.count, points.count >= 2 else { return nil }

        let width = (dict["width"] as? NSNumber)?.doubleValue ?? 0.004
        self.init(kind: kind,
                  points: kind.tracksEveryPoint ? points : [points[0], points[points.count - 1]],
                  colorIndex: (dict["color"] as? String)
                      .flatMap { Self.colorNames.firstIndex(of: $0.lowercased()) } ?? 0,
                  width: width.clamped(to: 0.0005...0.1))
    }
}

/// Maps between the editor's view points and the unit space annotations live in.
enum ImageFit {
    /// Where an aspect-fitted image lands inside `container`.
    static func rect(for image: CGSize, in container: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0, container.width > 0, container.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let scale = min(container.width / image.width, container.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(x: (container.width - size.width) / 2,
                      y: (container.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    static func unitPoint(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        guard rect.width > 0, rect.height > 0 else { return .zero }
        return CGPoint(x: (point.x - rect.minX) / rect.width, y: (point.y - rect.minY) / rect.height)
    }
}

enum AnnotationRenderer {

    static func draw(_ annotations: [Annotation], in context: inout GraphicsContext, size: CGSize) {
        for annotation in annotations {
            let width = annotation.width * size.width
            let color = annotation.color

            switch annotation.kind {
            case .pen, .highlight:
                guard let first = annotation.points.first else { continue }
                var path = Path()
                path.move(to: denormalize(first, size))
                for point in annotation.points.dropFirst() { path.addLine(to: denormalize(point, size)) }
                let isHighlight = annotation.kind == .highlight
                context.stroke(
                    path,
                    with: .color(color.opacity(isHighlight ? 0.35 : 1)),
                    style: StrokeStyle(lineWidth: isHighlight ? width * 5 : width, lineCap: .round, lineJoin: .round)
                )
            case .rectangle:
                context.stroke(Path(annotation.boundingRect(in: size)), with: .color(color),
                               style: StrokeStyle(lineWidth: width))
            case .ellipse:
                context.stroke(Path(ellipseIn: annotation.boundingRect(in: size)), with: .color(color),
                               style: StrokeStyle(lineWidth: width))
            case .arrow:
                guard let start = annotation.points.first, let end = annotation.points.last else { continue }
                let path = arrowPath(from: denormalize(start, size), to: denormalize(end, size),
                                     head: max(width * 4, size.width * 0.012))
                context.stroke(path, with: .color(color),
                               style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
        }
    }

    static func arrowPath(from start: CGPoint, to end: CGPoint, head: Double) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        let angle = atan2(end.y - start.y, end.x - start.x)
        for offset in [Double.pi * 0.82, -Double.pi * 0.82] {
            path.move(to: end)
            path.addLine(to: CGPoint(x: end.x + cos(angle + offset) * head,
                                     y: end.y + sin(angle + offset) * head))
        }
        return path
    }

    private static func denormalize(_ point: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
}

extension NSImage {
    /// Burns annotations into a copy at the capture's native resolution.
    @MainActor
    func annotated(with annotations: [Annotation]) -> NSImage? {
        let renderer = ImageRenderer(content:
            AnnotatedImage(image: self, annotations: annotations)
                .frame(width: size.width, height: size.height)
        )
        renderer.scale = ScreenshotManager.nativeScale(of: self)
        return renderer.nsImage
    }
}

/// The image with its annotations, rendered on screen and exported as-is.
struct AnnotatedImage: View {
    let image: NSImage
    let annotations: [Annotation]
    var live: Annotation?

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .overlay {
                Canvas { context, size in
                    var ctx = context
                    AnnotationRenderer.draw(annotations, in: &ctx, size: size)
                    if let live { AnnotationRenderer.draw([live], in: &ctx, size: size) }
                }
            }
    }
}
