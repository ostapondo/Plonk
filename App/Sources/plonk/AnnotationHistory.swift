import CoreGraphics

struct AnnotationHistory {
    private(set) var annotations: [Annotation] = []
    private var redoStack: [Annotation] = []
    private(set) var live: Annotation?

    var canUndo: Bool { !annotations.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    mutating func begin(_ kind: Annotation.Kind, at point: CGPoint, color: Int, width: Double) {
        live = Annotation(kind: kind, points: [point], colorIndex: color, width: width)
    }

    mutating func drag(to point: CGPoint) {
        guard var mark = live, let start = mark.points.first, mark.points.last != point else { return }
        if mark.kind.tracksEveryPoint {
            mark.points.append(point)
        } else {
            mark.points = point == start ? [start] : [start, point]
        }
        live = mark
    }

    mutating func end(at point: CGPoint) {
        drag(to: point)
        defer { live = nil }
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
}
