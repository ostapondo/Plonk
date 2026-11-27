import AppKit
import Testing
@testable import plonk

@MainActor
struct QuickShotRegionTests {
    @Test func restoredSelectionUsesTheNewBitmapAndShowsRegionControls() throws {
        let canvas = try makeCanvas()
        let rect = CGRect(x: 140, y: 200, width: 360, height: 280)
        canvas.installSelectionHint(canRestore: true)
        let hint = try #require(canvas.subviews.compactMap { $0 as? QuickShotHint }.first)
        #expect(hint.subviews.compactMap { $0 as? NSTextField }.map(\.stringValue)
            .contains(String(localized: .shotRestoreRegionHint)))
        #expect(hint.hitTest(.zero) == nil)

        #expect(canvas.selectRegion(rect))
        canvas.showSelectionHint(canvas.isWaitingForSelection)

        #expect(hint.isHidden)
        let backdrop = try #require(canvas.subviews.compactMap { $0 as? QuickShotBackdrop }.first)
        let controls = try #require(canvas.subviews.compactMap { $0 as? QuickShotDimensions }.first)
        let toolbar = try #require(canvas.subviews.compactMap { $0 as? QuickShotToolbar }.first)
        #expect(backdrop.selection == CGRect(x: 70, y: 100, width: 180, height: 140))
        #expect(!controls.isHidden)
        #expect(!toolbar.isHidden)

        var output: ShotCrop?
        canvas.onOutput = { _, crop in output = crop }
        canvas.handle(.save)
        let crop = try #require(output)
        #expect(crop.rect == rect)
        #expect(crop.history.annotations.isEmpty)
        let bitmap = try #require(crop.image.representations.first as? NSBitmapImageRep)
        #expect(bitmap.colorAt(x: 0, y: 0)?.redComponent == 1)
    }

    @Test func restoreKeepsTheCurrentGestureAndConfirmedSelection() throws {
        let canvas = try makeCanvas()
        let window = NSWindow(contentRect: canvas.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = canvas
        let start = CGPoint(x: 100, y: 100)
        let end = CGPoint(x: 280, y: 260)
        let previous = CGRect(x: 10, y: 30, width: 40, height: 50)
        canvas.mouseDown(with: try mouse(.leftMouseDown, at: start, in: canvas, window: window))
        #expect(!canvas.selectRegion(previous))
        canvas.mouseDragged(with: try mouse(.leftMouseDragged, at: end, in: canvas, window: window))
        #expect(!canvas.selectRegion(previous))
        canvas.mouseUp(with: try mouse(.leftMouseUp, at: end, in: canvas, window: window))
        #expect(!canvas.selectRegion(previous))

        var output: ShotCrop?
        canvas.onOutput = { _, crop in output = crop }
        canvas.handle(.save)
        #expect(output?.rect == CGRect(x: 200, y: 200, width: 360, height: 320))
    }

    @Test func missingRegionOmitsTheRestoreHint() throws {
        let canvas = try makeCanvas()
        canvas.installSelectionHint(canRestore: false)
        let hint = try #require(canvas.subviews.compactMap { $0 as? QuickShotHint }.first)
        #expect(hint.subviews.compactMap { $0 as? NSTextField }.map(\.stringValue)
            == [String(localized: .shotSelectDisplayHint)])
        #expect(canvas.isWaitingForSelection)
    }

    @Test(arguments: [true, false]) func onlyADesktopClickSelectsTheFullScreen(isDesktop: Bool) throws {
        let canvas = try makeCanvas()
        let window = NSWindow(contentRect: canvas.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = canvas
        canvas.isDesktop = { _ in isDesktop }
        canvas.onSelectDisplay = { [weak canvas] in canvas?.selectEntireDisplay() }

        let point = CGPoint(x: 200, y: 150)
        canvas.mouseDown(with: try mouse(.leftMouseDown, at: point, in: canvas, window: window))
        canvas.mouseUp(with: try mouse(.leftMouseUp, at: point, in: canvas, window: window))

        var output: ShotCrop?
        canvas.onOutput = { _, crop in output = crop }
        canvas.handle(.save)
        if isDesktop {
            #expect(output?.rect == CGRect(x: 0, y: 0, width: 1600, height: 1000))
        } else {
            #expect(canvas.isWaitingForSelection)
            #expect(output == nil)
        }
    }

    @Test func exactDimensionsAreUsedByTheSavedRetinaCrop() throws {
        let canvas = try makeCanvas()
        let frame = canvas.frame
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = canvas
        let start = try mouse(.leftMouseDown, at: CGPoint(x: 100, y: 100), in: canvas, window: window)
        let end = try mouse(.leftMouseUp, at: CGPoint(x: 280, y: 260), in: canvas, window: window)
        canvas.mouseDown(with: start)
        canvas.mouseUp(with: end)
        try verifyResizedOutput(in: canvas, window: window)
    }

    @Test func fullScreenSelectionCanBeResizedBeforeOutput() throws {
        let canvas = try makeCanvas()
        let window = NSWindow(contentRect: canvas.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = canvas
        canvas.selectEntireDisplay()
        try verifyResizedOutput(in: canvas, window: window)
    }

    private func makeCanvas() throws -> QuickShotCanvas {
        _ = NSApplication.shared
        let context = try #require(CGContext(
            data: nil, width: 1600, height: 1000, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 1600, height: 1000))
        let bitmap = ShotBitmap(image: try #require(context.makeImage()), displaySize: CGSize(width: 800, height: 500))
        let frame = CGRect(origin: .zero, size: bitmap.displaySize)
        return QuickShotCanvas(bitmap: bitmap, size: frame.size, safeArea: frame, fixed: false)
    }

    private func verifyResizedOutput(in canvas: QuickShotCanvas, window: NSWindow) throws {
        let controls = try #require(canvas.subviews.compactMap { $0 as? QuickShotDimensions }.first)
        #expect(canvas.selectDimension(at: controls.convert(CGPoint(x: 27, y: 14), to: nil)))
        try input("800", command: #selector(NSResponder.insertTab(_:)), in: window)
        try input("600", command: #selector(NSResponder.insertNewline(_:)), in: window)

        var output: ShotCrop?
        canvas.onOutput = { _, crop in output = crop }
        canvas.handle(.save)
        #expect(output?.rect.size == CGSize(width: 800, height: 600))
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
