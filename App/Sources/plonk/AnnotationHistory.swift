import CoreGraphics

struct AnnotationHistory {
    private(set) var annotations: [Annotation] = []
    private(set) var redoStack: [Annotation] = []
    private(set) var live: Annotation?

    mutating func begin(_ kind: Annotation.Kind, at point: CGPoint, color: Int, width: Double) {
        live = Annotation(kind: kind, points: [point], colorIndex: color, width: width)
    }

    mutating func drag(to point: CGPoint) {
        guard var annotation = live, let start = annotation.points.first else { return }
        if annotation.kind.tracksEveryPoint {
            annotation.points.append(point)
        } else {
            annotation.points = [start, point]
        }
        live = annotation
    }

    mutating func end() {
        defer { live = nil }
        guard let live, live.points.count > 1 else { return }
        append(live)
    }

    mutating func append(_ annotation: Annotation) {
        annotations.append(annotation)
        redoStack.removeAll()
    }

    mutating func undo() {
        if let last = annotations.popLast() { redoStack.append(last) }
    }

    mutating func redo() {
        if let last = redoStack.popLast() { annotations.append(last) }
    }

    func rebased(to crop: CGRect) -> Self {
        Self(annotations: annotations.map { $0.rebased(to: crop) },
             redoStack: redoStack.map { $0.rebased(to: crop) })
    }
}
