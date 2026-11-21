import AppKit
import Foundation
import SwiftUI
import Testing
@testable import plonk

@Suite(.serialized)
struct AnnotationStyleTests {
    @Test func legacyConfigLoadsEveryToolDefault() throws {
        let store = try loadConfig("""
        {"appearance":{"accentHex":"#1E62BC"}}
        """)

        #expect(store.loadFailure == nil)
        #expect(store.config.shotAnnotationStyles == defaults)
        #expect(store.config.appearance.accentHex == "#1E62BC")
    }

    @Test func partialConfigFillsMissingStyleFields() throws {
        let store = try loadConfig("""
        {"appearance":{"accentHex":"#8C31A6"},"shotAnnotationStyles":{"rectangle":{"color":"green"}}}
        """)
        var expected = defaults
        expected.rectangle.color = .green

        #expect(store.loadFailure == nil)
        #expect(store.config.shotAnnotationStyles == expected)
        #expect(store.config.appearance.accentHex == "#8C31A6")
    }

    @Test(arguments: Annotation.Kind.styleOrder)
    func widthWritesEachStepAndKeepsOtherTools(_ kind: Annotation.Kind) {
        let dir = TempDir()
        let store = ConfigStore(directory: dir.url)
        var expected = defaults

        for width in [21, 22] {
            store.update { $0[keyPath: kind.stylePath].width = width }
            expected[keyPath: stylePath(kind)].width = width

            let reopened = ConfigStore(directory: dir.url)
            reopened.load()
            #expect(reopened.config.shotAnnotationStyles == expected)
        }
    }

    @Test(arguments: Annotation.Kind.styleOrder)
    func colorWritesPreserveWidthsAndOtherTools(_ kind: Annotation.Kind) {
        let dir = TempDir()
        let store = ConfigStore(directory: dir.url)
        store.update { $0[keyPath: kind.stylePath].color = .purple }
        var expected = defaults
        expected[keyPath: stylePath(kind)].color = .purple

        let reopened = ConfigStore(directory: dir.url)
        reopened.load()
        #expect(reopened.config.shotAnnotationStyles == expected)
    }

    @Test(arguments: [
        DragCase(8, 0, 10), DragCase(0, 8, 10), DragCase(-8, 0, 6), DragCase(0, -8, 6),
        DragCase(4, 4, 10), DragCase(4, -4, 8), DragCase(3, 0, 8), DragCase(0, -3, 8),
        DragCase(-40, 0, 1), DragCase(0, -40, 1), DragCase(-24, 0, 2),
    ])
    func dragStepsTruncateAndClamp(_ drag: DragCase) {
        #expect(AnnotationStyle.draggedWidth(from: 8, horizontal: drag.horizontal,
                                             vertical: drag.vertical, in: 1...9999) == drag.width)
    }

    @Test(arguments: Annotation.Kind.styleOrder)
    func minimumAndMaximumRespectTheTool(_ kind: Annotation.Kind) {
        #expect(AnnotationStyle.draggedWidth(from: 8, horizontal: -100, vertical: 0, in: kind.widthRange)
            == (kind == .highlight ? 5 : 1))
        #expect(AnnotationStyle.draggedWidth(from: 9998, horizontal: 8, vertical: 0, in: kind.widthRange) == 9999)
    }

    @Test(arguments: Annotation.Kind.styleOrder)
    func redoKeepsEachMarksOriginalWidthAndColor(_ kind: Annotation.Kind) {
        var history = AnnotationHistory()
        for (index, style) in [AnnotationStyle(width: 8, color: .red),
                               AnnotationStyle(width: 16, color: .red),
                               AnnotationStyle(width: 16, color: .green)].enumerated() {
            let y = CGFloat(index + 1) / 8
            history.begin(kind, at: CGPoint(x: 0.125, y: y), style: style, pixelWidth: 1024)
            history.end(at: CGPoint(x: 0.5, y: y + 0.0625))
        }

        history.undo()
        history.redo()
        #expect(history.annotations.map { $0.width * 1024 } == [8, 16, 16])
        #expect(history.annotations.map(\.colorIndex) == [0, 0, 3])
        #expect(history.annotations.compactMap { $0.points.first?.y } == [0.125, 0.25, 0.375])
    }

    @MainActor
    @Test(arguments: Annotation.Kind.styleOrder)
    func pngRendersLargeWidthsAtSourceResolution(_ kind: Annotation.Kind) throws {
        var history = AnnotationHistory()
        draw(kind, y: 260, style: AnnotationStyle(width: 102, color: .green), into: &history, shapeHeight: 280)
        let rep = try renderCrop(history)
        #expect(rep.pixelsWide == 1000)
        #expect(rep.pixelsHigh == 600)

        let band = try (80...240).filter { y in
            let color = try #require(rep.colorAt(x: 550, y: y)?.usingColorSpace(.sRGB))
            return color.greenComponent - color.redComponent > 0.1
        }
        #expect(band == Array(109..<211))
        let center = try #require(rep.colorAt(x: 550, y: 160)?.usingColorSpace(.sRGB))
        #expect((center.redComponent > 0.6) == (kind == .highlight))
    }

    @MainActor
    @Test(arguments: Annotation.Kind.styleOrder)
    func cropRendersEachMarksOriginalStyleAtItsPosition(_ kind: Annotation.Kind) throws {
        var history = AnnotationHistory()
        let marks = [(185, AnnotationStyle(width: 8, color: .red)),
                     (350, AnnotationStyle(width: 16, color: .red)),
                     (515, AnnotationStyle(width: 16, color: .green))]
        for (y, style) in marks {
            draw(kind, y: CGFloat(y), style: style, into: &history, shapeHeight: 80)
        }

        let rep = try renderCrop(history)
        for (y, style) in marks {
            let center = y - 100
            let band = try ((center - 25)...(center + 25)).filter { pixel in
                let color = try #require(rep.colorAt(x: 550, y: pixel)?.usingColorSpace(.sRGB))
                let tint = color.redComponent - color.greenComponent
                return style.color == .red ? tint > 0.1 : tint < -0.1
            }
            #expect(band == Array((center - style.width / 2)..<(center + style.width / 2)))
        }
    }

    private let sourceImage = CGRect(x: 0, y: 0, width: 1200, height: 800)

    private func draw(_ kind: Annotation.Kind, y: CGFloat, style: AnnotationStyle,
                      into history: inout AnnotationHistory, shapeHeight: CGFloat) {
        let bottom = kind == .rectangle || kind == .ellipse ? y + shapeHeight : y
        history.begin(kind, at: ImageFit.unitPoint(CGPoint(x: 240, y: y), in: sourceImage),
                      style: style, pixelWidth: sourceImage.width)
        history.end(at: ImageFit.unitPoint(CGPoint(x: 1060, y: bottom), in: sourceImage))
    }

    @MainActor
    private func renderCrop(_ history: AnnotationHistory) throws -> NSBitmapImageRep {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: Int(sourceImage.width), height: Int(sourceImage.height), bitsPerComponent: 8,
            bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(NSColor.white.cgColor)
        context.fill(sourceImage)
        let image = try #require(context.makeImage())
        let bitmap = ShotBitmap(image: image, displaySize: CGSize(width: 600, height: 400))
        let selection = CGRect(x: 100, y: 100, width: 1000, height: 600)
        let crop = try #require(ShotCrop(bitmap: bitmap, rect: selection, history: history))
        let rendered = try #require(crop.rendered())
        let png = try #require(ScreenshotManager.pngData(from: rendered))
        return try #require(NSBitmapImageRep(data: png))
    }

    @MainActor
    @Test(arguments: [1, 2])
    func saturatedDialKeepsOnePixelBetweenDotAndRim(_ scale: Int) throws {
        let saturated = try dialScanline(width: 100, scale: scale)
        let increased = try dialScanline(width: 102, scale: scale)
        let initial = try dialScanline(width: 4, scale: scale)
        #expect(saturated == increased)
        #expect(initial.filter { $0 > 0.85 }.count < saturated.filter { $0 > 0.85 }.count)

        let leftGap = 7 * scale
        let rightGap = 30 * scale - 1
        for (gap, towardsDot) in [(leftGap, 1), (rightGap, -1)] {
            #expect(saturated[gap] < 0.35)
            #expect(saturated[gap + towardsDot] > 0.85)
            #expect((0.5..<0.85).contains(saturated[gap - towardsDot]))
        }
    }

    @MainActor
    private func dialScanline(width: Int, scale: Int) throws -> [CGFloat] {
        let view = AnnotationWidthControl(width: .constant(width), range: 1...9999, hovering: .constant(false))
            .environment(\.displayScale, CGFloat(scale))
        let renderer = ImageRenderer(content: view)
        renderer.scale = CGFloat(scale)
        let image = try #require(renderer.cgImage)
        let rep = NSBitmapImageRep(cgImage: image)
        return try (0..<rep.pixelsWide).map { x in
            let color = try #require(rep.colorAt(x: x, y: 33 * scale / 2)?.usingColorSpace(.sRGB))
            return color.redComponent
        }
    }

    struct DragCase {
        let horizontal: CGFloat
        let vertical: CGFloat
        let width: Int

        init(_ horizontal: CGFloat, _ vertical: CGFloat, _ width: Int) {
            self.horizontal = horizontal
            self.vertical = vertical
            self.width = width
        }
    }

    private var defaults: AnnotationStyles {
        let red = AnnotationStyle(width: 4, color: .red)
        return AnnotationStyles(rectangle: red, ellipse: red, arrow: red,
                                highlight: AnnotationStyle(width: 20, color: .yellow), pen: red)
    }

    private func stylePath(_ kind: Annotation.Kind) -> WritableKeyPath<AnnotationStyles, AnnotationStyle> {
        switch kind {
        case .rectangle: \.rectangle
        case .ellipse: \.ellipse
        case .arrow: \.arrow
        case .highlight: \.highlight
        case .pen: \.pen
        }
    }

    private func loadConfig(_ json: String) throws -> ConfigStore {
        let dir = TempDir()
        try Data(json.utf8).write(to: dir.url.appendingPathComponent("config.json"))
        let store = ConfigStore(directory: dir.url)
        store.load()
        return store
    }
}
