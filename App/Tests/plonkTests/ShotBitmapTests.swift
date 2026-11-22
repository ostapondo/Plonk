import AppKit
import Testing
@testable import plonk

struct ShotBitmapTests {
    @Test(arguments: [1, 2]) func cropPreservesPixelsAndLogicalSize(_ scale: Int) throws {
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 120 * scale, pixelsHigh: 90 * scale,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let image = try #require(rep.cgImage)
        let bitmap = ShotBitmap(image: image, displaySize: CGSize(width: 120, height: 90))
        let cropped = try #require(bitmap.crop(CGRect(x: 14, y: 8, width: 60, height: 40)))
        #expect(cropped.size == CGSize(width: 60 / CGFloat(scale), height: 40 / CGFloat(scale)))
        let png = try #require(ScreenshotManager.pngData(from: cropped))
        let output = try #require(NSBitmapImageRep(data: png))
        #expect(output.pixelsWide == 60)
        #expect(output.pixelsHigh == 40)
        #expect(abs(output.size.width - cropped.size.width) < 0.1)
    }
}
