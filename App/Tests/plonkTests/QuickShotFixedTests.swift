import AppKit
import Testing
@testable import plonk

@MainActor
struct QuickShotFixedTests {
    @Test func scaledImageAndToolbarBothFitInTheVisibleArea() {
        let area = CGRect(x: 0, y: 24, width: 400, height: 276)
        let original = CGSize(width: 602, height: 402)
        let layout = QuickShotLayout.fixed(image: original, toolbar: CGSize(width: 260, height: 42), area: area)

        #expect(area.contains(layout.image))
        #expect(area.contains(layout.toolbar))
        #expect(!layout.image.intersects(layout.toolbar))
        #expect(layout.image.width < original.width)
        #expect(abs(layout.image.width / layout.image.height - original.width / original.height) < 0.0001)
    }

    @Test func fixedCanvasHidesTheCropControls() throws {
        let canvas = try makeCanvas()
        let controls = try #require(canvas.subviews.compactMap { $0 as? QuickShotDimensions }.first)
        let toolbar = try #require(canvas.subviews.compactMap { $0 as? QuickShotToolbar }.first)

        #expect(controls.isHidden)
        #expect(!toolbar.isHidden)
        #expect(!toolbar.subviews.compactMap { $0 as? QuickShotButton }.contains {
            $0.accessibilityLabel() == String(localized: .shotSelectionMove)
        })
    }

    @Test func markedOutputKeepsTheCapturePixelsAfterScalingThePreview() throws {
        let canvas = try makeCanvas()
        let toolbar = try #require(canvas.subviews.compactMap { $0 as? QuickShotToolbar }.first)
        let pen = try #require(toolbar.subviews.compactMap { $0 as? QuickShotButton }.first {
            $0.accessibilityLabel() == String(localized: Annotation.Kind.pen.title)
        })
        let backdrop = try #require(canvas.subviews.compactMap { $0 as? QuickShotBackdrop }.first)
        pen.performClick(nil)
        try drawMark(in: canvas, imageFrame: backdrop.frame)
        var output: ShotCrop?
        canvas.onOutput = { _, crop in output = crop }

        canvas.handle(.save)

        let crop = try #require(output)
        #expect(crop.history.annotations.count == 1)
        let rendered = try #require(crop.rendered())
        let data = try #require(ScreenshotManager.pngData(from: rendered))
        let png = try #require(NSBitmapImageRep(data: data))
        #expect(png.pixelsWide == 1204)
        #expect(png.pixelsHigh == 804)
    }

    private func makeCanvas() throws -> QuickShotCanvas {
        _ = NSApplication.shared
        let context = try #require(CGContext(
            data: nil, width: 1204, height: 804, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let bitmap = ShotBitmap(image: try #require(context.makeImage()), displaySize: CGSize(width: 602, height: 402))
        let frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        return QuickShotCanvas(bitmap: bitmap, size: frame.size, safeArea: frame, fixed: true)
    }

    private func drawMark(in canvas: QuickShotCanvas, imageFrame: CGRect) throws {
        let window = NSWindow(contentRect: canvas.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = canvas
        let points: [(NSEvent.EventType, CGPoint)] = [
            (.leftMouseDown, CGPoint(x: imageFrame.minX + 20, y: imageFrame.midY)),
            (.leftMouseUp, CGPoint(x: imageFrame.maxX - 20, y: imageFrame.midY))
        ]
        for (type, point) in points {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: canvas.convert(point, to: nil), modifierFlags: [],
                timestamp: 0, windowNumber: window.windowNumber, context: nil,
                eventNumber: 0, clickCount: 1, pressure: 1))
            if type == .leftMouseDown {
                canvas.mouseDown(with: event)
            } else {
                canvas.mouseUp(with: event)
            }
        }
    }
}
