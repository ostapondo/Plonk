import CoreGraphics
import Foundation

final class ShotPixelSampler {
    struct Neighborhood {
        let image: CGImage
        let offset: CGPoint
    }

    private let image: CGImage
    private let pixelBounds: CGRect
    private lazy var colorContext: CGContext? = {
        guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let format = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        return CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                         space: sRGB, bitmapInfo: format)
    }()

    init(image: CGImage) {
        self.image = image
        pixelBounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    }

    // The canvas and crop use a top-left origin. Selection edges round to the
    // nearest boundary, while sampling floors to the pixel containing the point.
    func pixel(at point: CGPoint, in area: CGRect) -> CGPoint? {
        guard !area.isEmpty, area.contains(point) else { return nil }
        return CGPoint(x: floor((point.x - area.minX) / area.width * pixelBounds.width),
                       y: floor((point.y - area.minY) / area.height * pixelBounds.height))
    }

    func hex(at pixel: CGPoint) -> String? {
        let rect = CGRect(origin: pixel, size: CGSize(width: 1, height: 1))
        guard let source = image.cropping(to: rect), let colorContext,
              let bytes = colorContext.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        colorContext.setBlendMode(.copy)
        colorContext.draw(source, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let alpha = Int(bytes[3])
        guard alpha > 0 else { return nil }
        func channel(_ index: Int) -> Int { min(255, (Int(bytes[index]) * 255 + alpha / 2) / alpha) }
        return String(format: "#%02X%02X%02X", channel(0), channel(1), channel(2))
    }

    func neighborhood(around pixel: CGPoint, side: Int) -> Neighborhood? {
        let radius = CGFloat(side / 2)
        let requested = CGRect(x: pixel.x - radius, y: pixel.y - radius,
                               width: CGFloat(side), height: CGFloat(side))
        let available = requested.intersection(pixelBounds)
        guard let image = image.cropping(to: available) else { return nil }
        return Neighborhood(image: image, offset: CGPoint(x: available.minX - requested.minX,
                                                          y: available.minY - requested.minY))
    }
}
