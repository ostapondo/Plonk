import CoreGraphics

struct ShotRegionGesture {
    private static let windowDragThreshold: CGFloat = 4

    let start: CGPoint
    let startsOnWindow: Bool
    private(set) var end: CGPoint
    private(set) var isDragging = false

    init(start: CGPoint, startsOnWindow: Bool) {
        self.start = start
        self.startsOnWindow = startsOnWindow
        end = start
    }

    mutating func update(to point: CGPoint) {
        end = point
        guard !isDragging else { return }
        if startsOnWindow {
            isDragging = hypot(end.x - start.x, end.y - start.y) >= Self.windowDragThreshold
        } else {
            isDragging = end != start
        }
    }
}
