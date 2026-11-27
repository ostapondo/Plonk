struct ShotMagnifierZoom: Equatable {
    private static let range = 11...26
    static let standard = Self(pixelsPerRow: 18)

    let pixelsPerRow: Int

    // An odd crop keeps the sampled pixel centered and covers both viewport edges.
    var cells: Int { 2 * ((pixelsPerRow + 1) / 2) + 1 }

    func stepped(increasing: Bool) -> Self {
        Self(pixelsPerRow: (pixelsPerRow + (increasing ? -1 : 1)).clamped(to: Self.range))
    }
}
