import CoreGraphics

enum ShotMagnifierZoom: Int {
    case lowest, low, standard, high, highest

    static let gridWidth: CGFloat = 147
    var cells: Int { 15 - rawValue * 2 }
    var cellSize: CGFloat { floor(Self.gridWidth / CGFloat(cells)) }

    func stepped(increasing: Bool) -> Self {
        Self(rawValue: rawValue + (increasing ? 1 : -1)) ?? self
    }
}
