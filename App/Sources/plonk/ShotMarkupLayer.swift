import SwiftUI

struct ShotMarkupLayer: View {
    var history = AnnotationHistory()
    var imageRect = CGRect.zero
    var clip = CGRect.zero

    var body: some View {
        Canvas { context, _ in
            context.clip(to: Path(clip))
            context.translateBy(x: imageRect.minX, y: imageRect.minY)
            AnnotationRenderer.draw(history.annotations, in: &context, size: imageRect.size)
            if let live = history.live {
                AnnotationRenderer.draw([live], in: &context, size: imageRect.size)
            }
        }
    }
}
