import AppKit

struct ShotCrop {
    let image: NSImage
    let history: AnnotationHistory

    init?(bitmap: ShotBitmap, rect: CGRect, history: AnnotationHistory) {
        guard let image = bitmap.crop(rect) else { return nil }
        let selection = ShotSelection(pixels: bitmap.size, view: bitmap.displaySize)
        self.image = image
        self.history = history.rebased(to: selection.unitRect(rect))
    }

    @MainActor
    func rendered() -> NSImage? {
        history.annotations.isEmpty ? image : image.annotated(with: history.annotations)
    }
}
