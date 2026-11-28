import CoreGraphics

struct AnnotationHistory {
    private(set) var annotations: [Annotation] = []
    private var redoStack: [Annotation] = []
    private(set) var live: Annotation?
    private var lastDragPoint: CGPoint?

    var canUndo: Bool { !annotations.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// `viewWidth` is how wide the image is drawn on screen, in points: a width is what the
    /// stroke looks like while drawing, so 4 reads the same on a Retina and a standard display.
    mutating func begin(_ kind: Annotation.Kind, at point: CGPoint, style: AnnotationStyle, viewWidth: CGFloat) {
        begin(kind, at: point, color: style.color.index, width: Double(style.width) / Double(max(viewWidth, 1)))
    }

    mutating func begin(_ kind: Annotation.Kind, at point: CGPoint, color: Int, width: Double) {
        lastDragPoint = nil
        live = Annotation(kind: kind, points: [point], colorIndex: color, width: width)
    }

    mutating func drag(to point: CGPoint, squareIn imageSize: CGSize? = nil) {
        guard var mark = live, let start = mark.points.first else { return }
        lastDragPoint = point
        if mark.kind.tracksEveryPoint {
            guard mark.points.last != point else { return }
            mark.points.append(point)
        } else {
            let end: CGPoint
            if let imageSize, mark.kind.supportsSquareConstraint {
                end = Self.squareCorner(from: start, to: point, in: imageSize)
            } else {
                end = point
            }
            mark.points = point == start ? [start] : [start, end]
        }
        live = mark
    }

    @discardableResult
    mutating func updateSquareConstraint(in imageSize: CGSize?) -> Bool {
        guard let mark = live, mark.kind.supportsSquareConstraint, let lastDragPoint else { return false }
        drag(to: lastDragPoint, squareIn: imageSize)
        return live != mark
    }

    mutating func end(at point: CGPoint, squareIn imageSize: CGSize? = nil) {
        drag(to: point, squareIn: imageSize)
        defer {
            live = nil
            lastDragPoint = nil
        }
        guard let live, live.points.count > 1 else { return }
        annotations.append(live)
        redoStack.removeAll()
    }

    mutating func undo() {
        if let mark = annotations.popLast() { redoStack.append(mark) }
    }

    mutating func redo() {
        if let mark = redoStack.popLast() { annotations.append(mark) }
    }

    func rebased(to crop: CGRect) -> Self {
        Self(annotations: annotations.map { $0.rebased(to: crop) },
             redoStack: redoStack.map { $0.rebased(to: crop) })
    }

    private static func squareCorner(from start: CGPoint, to point: CGPoint, in imageSize: CGSize) -> CGPoint {
        guard imageSize.width > 0, imageSize.height > 0 else { return point }
        // A unit of x and a unit of y cover different distances on a non-square image.
        let dx = (point.x - start.x) * imageSize.width
        let dy = (point.y - start.y) * imageSize.height
        let side = max(abs(dx), abs(dy))
        return CGPoint(x: start.x + (dx < 0 ? -side : side) / imageSize.width,
                       y: start.y + (dy < 0 ? -side : side) / imageSize.height)
    }
}
