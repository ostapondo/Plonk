import AppKit
import Testing
@testable import plonk

struct ShotSelectionTests {
    private let selection = ShotSelection(pixels: CGSize(width: 1600, height: 1000),
                                          view: CGSize(width: 800, height: 500))

    @Test func olderConfigurationsDefaultToQuickActions() throws {
        let config = try Config.decode(Data(#"{"shotFolder":"~/Pictures"}"#.utf8))
        #expect(config.shotAfterCapture == .quickActions)
        #expect(config.shotFolder == "~/Pictures")
    }

    @Test func retinaPointsMapToTheDisplayBitmap() {
        let point = selection.pixelPoint(CGPoint(x: 142.5, y: 80))
        #expect(point == CGPoint(x: 285, y: 160))
        #expect(selection.viewRect(CGRect(origin: point, size: CGSize(width: 800, height: 600)))
            == CGRect(x: 142.5, y: 80, width: 400, height: 300))
    }

    @Test func widthAndHeightInputKeepTheBottomLeftCorner() {
        let rect = CGRect(x: 220, y: 200, width: 300, height: 400)
        #expect(selection.resize(rect, dimension: 800, horizontal: true, ratio: nil)
            == CGRect(x: 220, y: 200, width: 800, height: 400))
        #expect(selection.resize(rect, dimension: 300, horizontal: false, ratio: nil)
            == CGRect(x: 220, y: 300, width: 300, height: 300))
    }

    @Test func inputShiftsBeforeReducingTheSize() {
        let rect = CGRect(x: 1500, y: 35, width: 50, height: 50)
        #expect(selection.resize(rect, dimension: 400, horizontal: true, ratio: 1)
            == CGRect(x: 1200, y: 0, width: 400, height: 400))
        #expect(selection.resize(rect, dimension: 2000, horizontal: true, ratio: 1)
            == CGRect(x: 600, y: 0, width: 1000, height: 1000))
    }

    @Test func cornerDragKeepsTheOppositeCornerAndRatio() {
        let rect = CGRect(x: 400, y: 200, width: 600, height: 300)
        #expect(selection.drag(rect, handle: CGPoint(x: -1, y: -1),
                               delta: CGPoint(x: -100, y: -100), ratio: 2)
            == CGRect(x: 200, y: 100, width: 800, height: 400))
    }

    @Test(arguments: [1, 2])
    func cropProducesTheRequestedPNGDimensions(scale: Int) throws {
        let representation = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 1000 * scale, pixelsHigh: 800 * scale,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let source = NSImage(size: CGSize(width: 1000, height: 800))
        source.addRepresentation(representation)
        let image = try #require(ShotBitmap(source)?.crop(CGRect(x: 51, y: 23, width: 800, height: 600)))
        let data = try #require(ScreenshotManager.pngData(from: image))
        let png = try #require(NSBitmapImageRep(data: data))
        #expect(png.pixelsWide == 800)
        #expect(png.pixelsHigh == 600)
    }
}
