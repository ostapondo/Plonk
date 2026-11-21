import SwiftUI

struct AnnotationLayer: View {
    let annotations: [Annotation]
    var live: Annotation?
    var clip: CGRect?

    var body: some View {
        Canvas { context, size in
            var context = context
            if let clip { context.clip(to: Path(clip)) }
            AnnotationRenderer.draw(annotations, in: &context, size: size)
            if let live { AnnotationRenderer.draw([live], in: &context, size: size) }
        }
    }
}
