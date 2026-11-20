import AppKit
import Testing
@testable import plonk

@MainActor
struct ShotCropTests {
    @Test func editorReceivesTheUnmarkedCrop() throws {
        let crop = try annotatedCrop(scale: 2)
        let base = try bitmapRep(crop.image)
        #expect(try isWhite(base, atX: 40, y: 40))
        #expect(crop.history.canUndo)
    }

    @Test(arguments: [1, 2]) func outputKeepsThePixelAndPointDimensions(_ scale: Int) throws {
        let crop = try annotatedCrop(scale: scale)
        let image = try #require(crop.rendered())
        let rep = try bitmapRep(image)
        #expect(rep.pixelsWide == 80 * scale)
        #expect(rep.pixelsHigh == 60 * scale)
        #expect(image.size == CGSize(width: 80, height: 60))
        #expect(abs(rep.size.width - 80) < 0.1)
    }

    @Test func outputClipsTheMarkAtTheCropEdge() throws {
        let crop = try annotatedCrop(scale: 2)
        let image = try #require(crop.rendered())
        let rep = try bitmapRep(image)
        let edge = try #require(rep.colorAt(x: 0, y: 40)?.usingColorSpace(.sRGB))
        #expect(edge.redComponent > 0.8 && edge.greenComponent < 0.4)
        #expect(try isWhite(rep, atX: 40, y: 70))
    }

    private func annotatedCrop(scale: Int) throws -> ShotCrop {
        let width = 200 * scale
        let height = 120 * scale
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let bitmap = ShotBitmap(image: image, displaySize: CGSize(width: 200, height: 120))
        let rect = CGRect(x: 40 * scale, y: 20 * scale, width: 80 * scale, height: 60 * scale)
        var history = AnnotationHistory()
        history.begin(.pen, at: CGPoint(x: 0.1, y: 1.0 / 3), color: 0, width: 0.02)
        history.end(at: CGPoint(x: 0.7, y: 1.0 / 3))
        return try #require(ShotCrop(bitmap: bitmap, rect: rect, history: history))
    }

    private func bitmapRep(_ image: NSImage) throws -> NSBitmapImageRep {
        let png = try #require(ScreenshotManager.pngData(from: image))
        return try #require(NSBitmapImageRep(data: png))
    }

    private func isWhite(_ rep: NSBitmapImageRep, atX x: Int, y: Int) throws -> Bool {
        let color = try #require(rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        return min(color.redComponent, color.greenComponent, color.blueComponent) > 0.95
    }
}
