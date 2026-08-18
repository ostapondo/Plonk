import Testing
import AppKit
@testable import plonk

struct ImageFitTests {

    @Test func wideImageInATallPaneIsLetterboxedVertically() {
        let rect = ImageFit.rect(for: CGSize(width: 200, height: 100), in: CGSize(width: 200, height: 200))
        #expect(rect.width == 200)
        #expect(rect.height == 100)
        #expect(rect.minY == 50)
        #expect(rect.minX == 0)
    }

    @Test func tallImageInAWidePaneIsPillarboxed() {
        let rect = ImageFit.rect(for: CGSize(width: 100, height: 200), in: CGSize(width: 400, height: 200))
        #expect(rect.width == 100)
        #expect(rect.minX == 150)
    }

    @Test func degenerateSizesFallBackToTheContainer() {
        let rect = ImageFit.rect(for: .zero, in: CGSize(width: 300, height: 200))
        #expect(rect.size == CGSize(width: 300, height: 200))
    }

    @Test func cornersOfTheFittedImageMapToTheUnitSquare() {
        let rect = ImageFit.rect(for: CGSize(width: 200, height: 100), in: CGSize(width: 200, height: 200))
        let topLeft = ImageFit.unitPoint(CGPoint(x: 0, y: 50), in: rect)
        let bottomRight = ImageFit.unitPoint(CGPoint(x: 200, y: 150), in: rect)
        #expect(abs(topLeft.x) < 0.001 && abs(topLeft.y) < 0.001)
        #expect(abs(bottomRight.x - 1) < 0.001 && abs(bottomRight.y - 1) < 0.001)
    }

    /// The whole point of unit coordinates: a mark drawn in the editor has to
    /// land in the same relative spot when the export renders at another size.
    @Test func aPointKeepsItsRelativePositionAcrossSizes() {
        let editor = ImageFit.rect(for: CGSize(width: 1440, height: 900), in: CGSize(width: 676, height: 500))
        let unit = ImageFit.unitPoint(CGPoint(x: editor.midX, y: editor.midY), in: editor)
        #expect(abs(unit.x - 0.5) < 0.001)
        #expect(abs(unit.y - 0.5) < 0.001)

        let exported = CGPoint(x: unit.x * 2880, y: unit.y * 1800)
        #expect(abs(exported.x - 1440) < 0.5)
        #expect(abs(exported.y - 900) < 0.5)
    }
}

struct AnnotationTests {

    @Test func boundingRectScalesWithTheCanvas() {
        let annotation = Annotation(kind: .rectangle,
                                    points: [CGPoint(x: 0.25, y: 0.5), CGPoint(x: 0.75, y: 0.25)],
                                    colorIndex: 0, width: 0.01)
        let rect = annotation.boundingRect(in: CGSize(width: 400, height: 200))
        #expect(rect.minX == 100)
        #expect(rect.minY == 50)
        #expect(rect.width == 200)
        #expect(rect.height == 50)
    }

    @Test func colorIndexIsClampedToThePalette() {
        #expect(Annotation(kind: .pen, points: [], colorIndex: 99, width: 0.01).color == Annotation.palette.last)
        #expect(Annotation(kind: .pen, points: [], colorIndex: -3, width: 0.01).color == Annotation.palette.first)
    }

    @Test func onlyFreehandKindsKeepEveryPoint() {
        #expect(Annotation.Kind.pen.tracksEveryPoint)
        #expect(Annotation.Kind.highlight.tracksEveryPoint)
        #expect(!Annotation.Kind.arrow.tracksEveryPoint)
        #expect(!Annotation.Kind.rectangle.tracksEveryPoint)
    }

    @Test func arrowHeadSitsBehindTheTip() {
        let path = AnnotationRenderer.arrowPath(from: .zero, to: CGPoint(x: 100, y: 0), head: 10)
        let bounds = path.boundingRect
        #expect(bounds.maxX <= 100.001)
        #expect(bounds.minX >= -0.001)
    }
}

struct ScreenshotManagerTests {

    @Test func fileNameIsSortableAndLocaleIndependent() {
        let date = Date(timeIntervalSince1970: 0)
        let name = ScreenshotManager.fileName(for: date)
        #expect(name.hasPrefix("Plonk "))
        #expect(name.hasSuffix(".png"))
        #expect(name.contains(" at "))
    }

    @Test func explicitPathGainsAnExtensionWhenMissing() {
        #expect(ScreenshotManager.Destination.path("/tmp/shot").url.lastPathComponent == "shot.png")
        #expect(ScreenshotManager.Destination.path("/tmp/shot.PNG").url.lastPathComponent == "shot.PNG")
    }

    @Test func folderDestinationExpandsTheTilde() {
        let url = ScreenshotManager.Destination.folder("~/Desktop").url
        #expect(!url.path.contains("~"))
        #expect(url.deletingLastPathComponent().lastPathComponent == "Desktop")
    }

    /// An image whose one bitmap holds `pixels` for `points` on screen.
    private func image(points: NSSize, pixels: NSSize) -> NSImage {
        let image = NSImage(size: points)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(pixels.width),
                                   pixelsHigh: Int(pixels.height), bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = points
        image.addRepresentation(rep)
        return image
    }

    @Test func nativeScaleReflectsThePixelBacking() {
        let image = image(points: NSSize(width: 100, height: 50), pixels: NSSize(width: 200, height: 100))
        #expect(abs(ScreenshotManager.nativeScale(of: image) - 2) < 0.001)
    }

    @Test func downscaleIsSkippedWhenTheImageAlreadyFits() {
        let image = image(points: NSSize(width: 100, height: 50), pixels: NSSize(width: 100, height: 50))
        #expect(ScreenshotManager.downscaled(image, maxDimension: 1568) == nil)
    }

    @Test func downscaleCapsTheLongestSide() throws {
        let image = image(points: NSSize(width: 4000, height: 1000), pixels: NSSize(width: 4000, height: 1000))
        let small = try #require(ScreenshotManager.downscaled(image, maxDimension: 1000))
        #expect(abs(small.size.width - 1000) < 1)
        #expect(abs(small.size.height - 250) < 1)
    }
}

