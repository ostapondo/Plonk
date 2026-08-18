import AppKit

// The frozen screens a measurement is taken against, and the two coordinate
// spaces they sit between.
//
// Everything the ruler answers is in CG space — origin at the top-left of the
// primary display, y downward — because that is what captures, window frames
// and the API all speak. AppKit puts its origin at the bottom-left, so the
// pointer has to be turned round on the way in and the drawing on the way out.

struct RulerSheet {
    let index: Int
    /// CG space, points.
    let frame: CGRect
    let visible: CGRect
    let grid: PixelGrid
    /// Pixels per point, measured from the picture rather than assumed: a
    /// capture of a Retina display comes back at twice the points, and that
    /// ratio is what every conversion here uses.
    let scale: CGFloat

    /// A screen before it has been photographed.
    struct ScreenFrame {
        let index: Int
        let frame: CGRect
        let visible: CGRect
        /// What the display reports before anything is photographed, for the
        /// measurements that need no picture at all.
        let scale: CGFloat
    }

    /// Every screen in CG space, which is the flip of what NSScreen reports.
    static func screens() -> [ScreenFrame] {
        NSScreen.screens.enumerated().map { index, screen in
            ScreenFrame(index: index, frame: CGSpace.flip(screen.frame),
                        visible: CGSpace.flip(screen.visibleFrame), scale: screen.backingScaleFactor)
        }
    }

    /// Photographs each of them and hands back the ones that came out, in the
    /// order they were asked for. Runs on the main queue, as every capture in
    /// this app does.
    static func capture(_ wanted: [ScreenFrame], completion: @escaping ([RulerSheet]) -> Void) {
        var sheets: [Int: RulerSheet] = [:]
        let group = DispatchGroup()
        for screen in wanted where screen.frame.width > 0 {
            group.enter()
            ScreenshotManager.captureRegion(screen.frame) { image in
                defer { group.leave() }
                guard let image,
                      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
                      let grid = PixelGrid(image: cgImage) else { return }
                sheets[screen.index] = RulerSheet(
                    index: screen.index, frame: screen.frame, visible: screen.visible, grid: grid,
                    scale: CGFloat(cgImage.width) / screen.frame.width
                )
            }
        }
        group.notify(queue: .main) {
            completion(wanted.compactMap { sheets[$0.index] })
        }
    }
}
