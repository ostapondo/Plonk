import AppKit

struct ShotBitmap {
    let image: CGImage
    let displaySize: CGSize
    var size: CGSize { CGSize(width: image.width, height: image.height) }

    init(image: CGImage, displaySize: CGSize) {
        self.image = image
        self.displaySize = displaySize
    }

    init?(capture: NSImage?, displaySize: CGSize? = nil) {
        guard let capture, let image = capture.representations.compactMap({ $0 as? NSBitmapImageRep })
            .max(by: { $0.pixelsWide < $1.pixelsWide })?.cgImage else { return nil }
        self.init(image: image, displaySize: displaySize ?? capture.size)
    }

    func crop(_ rect: CGRect) -> NSImage? {
        guard let cropped = image.cropping(to: rect) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cropped)
        rep.size = CGSize(width: CGFloat(cropped.width) / size.width * displaySize.width,
                          height: CGFloat(cropped.height) / size.height * displaySize.height)
        let result = NSImage(size: rep.size)
        result.addRepresentation(rep)
        return result
    }
}
