import AppKit
import Testing
@testable import plonk

@MainActor
struct QuickShotFixedTests {
    @Test func scaledImageAndToolbarBothFitInTheVisibleArea() {
        let area = CGRect(x: 0, y: 24, width: 400, height: 276)
        let original = CGSize(width: 602, height: 402)
        let layout = QuickShotLayout.fixed(image: original, toolbar: CGSize(width: 260, height: 42),
                                           reserve: QuickShotStyleControls.size.height, area: area)

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

    @Test func canvasDrawsWithTheCaptureStyle() throws {
        let annotation = ShotAnnotationState(defaults: .init())
        annotation.styles.rectangle = .init(width: 5, color: .green)
        let canvas = try makeCanvas(annotation: annotation)
        let toolbar = try #require(canvas.subviews.compactMap { $0 as? QuickShotToolbar }.first)
        let rectangle = try #require(toolbar.subviews.compactMap { $0 as? QuickShotButton }.first {
            $0.accessibilityLabel() == String(localized: Annotation.Kind.rectangle.title)
        })
        let backdrop = try #require(canvas.subviews.compactMap { $0 as? QuickShotBackdrop }.first)
        rectangle.performClick(nil)
        try drawMark(in: canvas, imageFrame: backdrop.frame)
        var output: ShotCrop?
        canvas.onOutput = { _, crop in output = crop }

        canvas.handle(.save)

        let mark = try #require(output?.history.annotations.first)
        #expect(mark.kind == .rectangle)
        #expect(mark.colorIndex == AnnotationColor.green.index)
        #expect(abs(mark.width * backdrop.frame.width - 5) < 0.0001)
    }

    @Test(arguments: [false, true])
    func shiftUpdatesTheLiveShapeWithoutMovingThePointer(shiftAtRelease: Bool) throws {
        let annotation = ShotAnnotationState(defaults: .init())
        annotation.tool = .ellipse
        let canvas = try makeCanvas(annotation: annotation)
        let window = NSWindow(contentRect: canvas.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = canvas
        let markup = try #require(canvas.subviews.compactMap { $0 as? QuickShotMarkupView }.first)
        let start = CGPoint(x: markup.frame.minX + 20, y: markup.frame.minY + 20)
        let end = CGPoint(x: start.x + 60, y: start.y + 20)
        canvas.mouseDown(with: try mouse(.leftMouseDown, at: start, in: canvas, window: window))
        canvas.mouseDragged(with: try mouse(.leftMouseDragged, at: end, in: canvas, window: window))
        let free = try #require(markup.rootView.live)
        #expect(abs(free.boundingRect(in: markup.frame.size).height - 20) < 0.0001)

        canvas.flagsChanged(with: try shiftEvent(down: true))
        let constrained = try #require(markup.rootView.live)
        #expect(abs(constrained.boundingRect(in: markup.frame.size).height - 60) < 0.0001)
        if !shiftAtRelease { canvas.flagsChanged(with: try shiftEvent(down: false)) }
        let preview = try #require(markup.rootView.live)
        #expect(preview == (shiftAtRelease ? constrained : free))

        canvas.mouseUp(with: try mouse(.leftMouseUp, at: end, in: canvas, window: window,
                                       flags: shiftAtRelease ? .shift : []))
        canvas.flagsChanged(with: try shiftEvent(down: false))
        #expect(markup.rootView.live == nil)
        #expect(markup.rootView.annotations == [preview])
    }

    private func makeCanvas(annotation: ShotAnnotationState? = nil) throws -> QuickShotCanvas {
        _ = NSApplication.shared
        let context = try #require(CGContext(
            data: nil, width: 1204, height: 804, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let bitmap = ShotBitmap(image: try #require(context.makeImage()), displaySize: CGSize(width: 602, height: 402))
        let frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        return QuickShotCanvas(bitmap: bitmap, size: frame.size, safeArea: frame, fixed: true, annotation: annotation)
    }

    private func drawMark(in canvas: QuickShotCanvas, imageFrame: CGRect) throws {
        let window = NSWindow(contentRect: canvas.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = canvas
        let points: [(NSEvent.EventType, CGPoint)] = [
            (.leftMouseDown, CGPoint(x: imageFrame.minX + 20, y: imageFrame.midY)),
            (.leftMouseUp, CGPoint(x: imageFrame.maxX - 20, y: imageFrame.midY))
        ]
        for (type, point) in points {
            let event = try mouse(type, at: point, in: canvas, window: window)
            if type == .leftMouseDown {
                canvas.mouseDown(with: event)
            } else {
                canvas.mouseUp(with: event)
            }
        }
    }

    private func mouse(_ type: NSEvent.EventType, at point: CGPoint, in canvas: QuickShotCanvas, window: NSWindow,
                       flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(with: type, location: canvas.convert(point, to: nil), modifierFlags: flags,
                                         timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                         eventNumber: 0, clickCount: 1, pressure: 1))
    }

    private func shiftEvent(down: Bool) throws -> NSEvent {
        let event = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 56, keyDown: down))
        event.type = .flagsChanged
        event.flags = down ? .maskShift : []
        return try #require(NSEvent(cgEvent: event))
    }
}
