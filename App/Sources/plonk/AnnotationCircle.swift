import SwiftUI

struct AnnotationCircle: View {
    struct Stroke {
        let color: Color
        let width: CGFloat
        var inset: CGFloat = 0
    }

    let fill: Color
    let fillInset: CGFloat
    var background: Color = .clear
    let strokes: [Stroke]

    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.fill(Path(ellipseIn: bounds), with: .color(background))
            let dot = bounds.insetBy(dx: fillInset, dy: fillInset)
            context.fill(Path(ellipseIn: dot), with: .color(fill))
            for stroke in strokes {
                let inset = stroke.inset + stroke.width / 2
                let ellipse = bounds.insetBy(dx: inset, dy: inset)
                context.stroke(Path(ellipseIn: ellipse), with: .color(stroke.color), lineWidth: stroke.width)
            }
        }
    }
}
