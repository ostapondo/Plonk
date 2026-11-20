import AppKit

struct ShotBitmap {
    let image: CGImage
    let displaySize: CGSize
    var size: CGSize { CGSize(width: image.width, height: image.height) }

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
