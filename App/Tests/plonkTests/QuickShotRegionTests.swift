import AppKit
import Testing
@testable import plonk

@MainActor
struct QuickShotRegionTests {
    @Test func hexIsHiddenAsSoonAsThePointerCreatesAnArea() throws {
        _ = NSApplication.shared
        let context = try #require(CGContext(
            data: nil, width: 800, height: 800, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let size = CGSize(width: 400, height: 400)
        let bitmap = ShotBitmap(image: try #require(context.makeImage()), displaySize: size)
        let frame = CGRect(origin: .zero, size: size)
        let canvas = QuickShotCanvas(bitmap: bitmap, size: size, safeArea: frame, fixed: false)
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = canvas
        let magnifier = try #require(canvas.magnifier)

        func event(_ type: NSEvent.EventType, _ x: CGFloat, _ y: CGFloat) throws -> NSEvent {
            try mouse(type, at: CGPoint(x: x, y: y), in: canvas, window: window)
        }

        #expect(magnifier.showsHex)
        canvas.mouseDown(with: try event(.leftMouseDown, 100, 100))
        #expect(canvas.isDraggingRegionBoundary && magnifier.showsHex)
        canvas.mouseDragged(with: try event(.leftMouseDragged, 160, 100))
        #expect(canvas.regionFrame == nil && magnifier.showsHex)

        canvas.mouseDragged(with: try event(.leftMouseDragged, 240, 240))
        #expect(canvas.regionFrame != nil && !magnifier.showsHex)
        canvas.mouseDragged(with: try event(.leftMouseDragged, 100, 100))
        #expect(canvas.regionFrame == nil && magnifier.showsHex)
        canvas.mouseUp(with: try event(.leftMouseUp, 240, 240))
        #expect(canvas.regionFrame != nil && !canvas.isDraggingRegionBoundary && !magnifier.showsHex)

        canvas.mouseDown(with: try event(.leftMouseDown, 240, 170))
        #expect(canvas.isDraggingRegionBoundary && !magnifier.showsHex)
        canvas.mouseUp(with: try event(.leftMouseUp, 260, 170))
        #expect(canvas.regionFrame?.maxX == 260 && !canvas.isDraggingRegionBoundary && !magnifier.showsHex)
        canvas.clearSelection()
        #expect(magnifier.showsHex)
        canvas.handle(.selectDisplay)
        #expect(canvas.regionFrame == frame && !magnifier.showsHex)
    }

    @Test func exactDimensionsAreUsedByTheSavedRetinaCrop() throws {
        _ = NSApplication.shared
        let context = try #require(CGContext(
            data: nil, width: 1600, height: 1000, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let bitmap = ShotBitmap(image: try #require(context.makeImage()), displaySize: CGSize(width: 800, height: 500))
        let frame = CGRect(origin: .zero, size: bitmap.displaySize)
        let canvas = QuickShotCanvas(bitmap: bitmap, size: frame.size, safeArea: frame, fixed: false)
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = canvas
        let start = try mouse(.leftMouseDown, at: CGPoint(x: 100, y: 100), in: canvas, window: window)
        let end = try mouse(.leftMouseUp, at: CGPoint(x: 280, y: 260), in: canvas, window: window)
        canvas.mouseDown(with: start)
        canvas.mouseUp(with: end)
        let controls = try #require(canvas.subviews.compactMap { $0 as? QuickShotDimensions }.first)
        #expect(canvas.selectDimension(at: controls.convert(CGPoint(x: 27, y: 14), to: nil)))
        try input("800", command: #selector(NSResponder.insertTab(_:)), in: window)
        try input("600", command: #selector(NSResponder.insertNewline(_:)), in: window)

        var output: ShotCrop?
        canvas.onOutput = { _, crop in output = crop }
        canvas.handle(.save)
        let rendered = try #require(output?.rendered())
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).png")
        defer { try? FileManager.default.removeItem(at: file) }
        let path = try #require(ScreenshotManager.save(rendered, to: .path(file.path)))
        let png = try #require(NSBitmapImageRep(data: Data(contentsOf: URL(fileURLWithPath: path))))
        #expect(png.pixelsWide == 800)
        #expect(png.pixelsHigh == 600)
    }

    private func mouse(_ type: NSEvent.EventType, at point: CGPoint, in view: NSView, window: NSWindow) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(with: type, location: view.convert(point, to: nil), modifierFlags: [],
                                         timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                         eventNumber: 0, clickCount: 1, pressure: 1))
    }

    private func input(_ text: String, command: Selector, in window: NSWindow) throws {
        let editor = try #require(window.firstResponder as? NSTextView)
        editor.insertText(text, replacementRange: editor.selectedRange())
        editor.doCommand(by: command)
    }
}
