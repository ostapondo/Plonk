import AppKit

struct ShotBitmap {
    let image: CGImage
    var size: CGSize { CGSize(width: image.width, height: image.height) }

    init?(_ source: NSImage) {
        guard let image = source.representations.compactMap({ $0 as? NSBitmapImageRep })
            .max(by: { $0.pixelsWide < $1.pixelsWide })?.cgImage else { return nil }
        self.image = image
    }

    func crop(_ rect: CGRect) -> NSImage? {
        guard let crop = image.cropping(to: rect) else { return nil }
        let representation = NSBitmapImageRep(cgImage: crop)
        let result = NSImage(size: representation.size)
        result.addRepresentation(representation)
        return result
    }
}
