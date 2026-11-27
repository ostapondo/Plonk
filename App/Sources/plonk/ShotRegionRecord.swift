import CoreGraphics

struct ShotRegionRecord {
    struct Display: Equatable {
        let uuid: String
        let pixels: CGSize
        let points: CGSize
        let scale: CGFloat
    }

    let display: Display
    let rect: CGRect

    func rect(on display: Display?) -> CGRect? {
        guard let display, display == self.display, !rect.isEmpty,
              CGRect(origin: .zero, size: display.pixels).contains(rect) else { return nil }
        return rect
    }
}
