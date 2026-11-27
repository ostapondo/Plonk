import AppKit
import Testing
@testable import plonk

@MainActor
struct QuickShotMagnifierTests {
    @Test(arguments: [1, 2])
    func pixelEdgesMoveWithTheFractionalPointerPosition(scale: Int) throws {
        _ = NSApplication.shared
        let magnifier = QuickShotMagnifier(image: try sourceImage(scale: scale))
        let area = CGRect(x: 0, y: 0, width: 400, height: 400)
        let window = NSWindow(contentRect: area, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView?.addSubview(magnifier)
        let zoom = ShotMagnifierZoom.standard
        func pointer(_ fraction: CGFloat) -> CGPoint {
            let position = 200 + fraction / CGFloat(scale)
            return CGPoint(x: position, y: position)
        }

        magnifier.update(at: pointer(0.1), in: area, avoiding: nil, zoom: zoom)
        let shown = try render(magnifier, scale: scale)
        #expect(rgb(shown, 116 * scale, 118 * scale) == [34, 34, 34])
        #expect(magnifier.hex == "#333359")

        magnifier.showsHex = false
        let before = try render(magnifier, scale: scale)
        #expect(rgb(before, 116 * scale, 118 * scale) == [204, 204, 89])
        #expect(rgb(before, 65 * scale, 75 * scale)[0] == 51)
        #expect(rgb(before, 75 * scale, 65 * scale)[1] == 51)

        magnifier.needsDisplay = false
        magnifier.update(at: pointer(0.9), in: area, avoiding: nil, zoom: zoom)
        #expect(magnifier.needsDisplay)
        let after = try render(magnifier, scale: scale)
        #expect(magnifier.hex == "#333359")
        #expect(rgb(after, 65 * scale, 75 * scale)[0] == 204)
        #expect(rgb(after, 75 * scale, 65 * scale)[1] == 204)

        for zoom in [ShotMagnifierZoom(pixelsPerRow: 11), ShotMagnifierZoom(pixelsPerRow: 26)] {
            let point = pointer(0.25)
            magnifier.update(at: point, in: area, avoiding: nil, zoom: .standard)
            magnifier.setZoom(zoom)
            let drawing = try render(magnifier, scale: scale)
            let expectedEdge = (62 + 0.75 * 120 / CGFloat(zoom.pixelsPerRow)) * CGFloat(scale)
            let horizontal = try #require((64 * scale..<77 * scale).first { rgb(drawing, $0, 80 * scale)[0] == 204 })
            let vertical = try #require((64 * scale..<77 * scale).first { rgb(drawing, 80 * scale, $0)[1] == 204 })
            #expect(abs(CGFloat(horizontal) - expectedEdge) <= 1)
            #expect(abs(CGFloat(vertical) - expectedEdge) <= 1)
        }
    }

    private func sourceImage(scale: Int) throws -> CGImage {
        let side = 400 * scale
        let bitmap = try context(width: side, height: side)
        let data = try #require(bitmap.data).assumingMemoryBound(to: UInt8.self)
        let edge = 200 * scale + 1
        for y in 0..<side {
            for x in 0..<side {
                let index = 4 * (y * side + x)
                data[index] = x < edge ? 51 : 204
                data[index + 1] = y < edge ? 51 : 204
                data[index + 2] = 89
                data[index + 3] = 255
            }
        }
        return try #require(bitmap.makeImage())
    }

    private func render(_ magnifier: QuickShotMagnifier, scale: Int) throws -> CGContext {
        let bitmap = try context(width: Int(magnifier.bounds.width) * scale, height: Int(magnifier.bounds.height) * scale)
        bitmap.translateBy(x: 0, y: CGFloat(bitmap.height))
        bitmap.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmap, flipped: true)
        magnifier.draw(magnifier.bounds)
        return bitmap
    }

    private func context(width: Int, height: Int) throws -> CGContext {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let format = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        return try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: space, bitmapInfo: format))
    }

    private func rgb(_ bitmap: CGContext, _ x: Int, _ y: Int) -> [UInt8] {
        let offset = y * bitmap.bytesPerRow + x * 4
        let pixel = bitmap.data!.assumingMemoryBound(to: UInt8.self) + offset
        return [pixel[0], pixel[1], pixel[2]]
    }
}
