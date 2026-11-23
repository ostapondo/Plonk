import SwiftUI

struct AnnotationWidthControl: View {
    static let size = CGSize(width: 37, height: 33)

    @Binding var width: Int
    let range: ClosedRange<Int>
    @Binding var hovering: Bool
    @Environment(\.displayScale) private var displayScale
    @State private var dragWidths: (start: Int, last: Int)?

    private let diameter: CGFloat = 25
    private let rim: CGFloat = 1
    private let surface = Color(white: 0.23)
    private let ink = Color(white: 0.94)

    var body: some View {
        ZStack(alignment: .topLeading) {
            dial
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
                .onContinuousHover { phase in
                    guard dragWidths == nil else { return }
                    switch phase {
                    case .active(let location): updateHover(at: location)
                    case .ended: hovering = false
                    }
                }
                .gesture(drag)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(.shotEditorWidth))
                .accessibilityValue(Text(.annotationWidthValue(width)))
                .accessibilityHint(Text(.annotationWidthDragHelp))
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: width = min(width + 1, range.upperBound)
                    case .decrement: width = max(width - 1, range.lowerBound)
                    @unknown default: break
                    }
                }
                .offset(x: 6, y: 4)

            if hovering {
                directions
            }
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            if hovering {
                Text(.annotationWidthValue(width))
                    .font(.system(size: 9, weight: .semibold).monospacedDigit())
                    .foregroundStyle(ink)
                    .fixedSize()
                    .frame(width: 53, alignment: .trailing)
                    .offset(y: 27)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private var dial: some View {
        let pixel = 1 / displayScale
        let fill = (6 + 0.65 * CGFloat(width - 1)).rounded()
        let dotInset = max((diameter - fill) / 2, rim + pixel)
        return AnnotationCircle(fill: ink, fillInset: dotInset, background: surface,
                                strokes: [.init(color: ink.opacity(0.68), width: rim)])
    }

    private var directions: some View {
        Path { path in
            let center = CGPoint(x: 6 + diameter / 2, y: 4 + diameter / 2)
            let distance: CGFloat = diameter / 2 + 2
            for (x, y) in [(CGFloat(0), CGFloat(-1)), (1, 0), (0, 1), (-1, 0)] {
                let tip = CGPoint(x: center.x + x * distance, y: center.y + y * distance)
                let base = CGPoint(x: tip.x - 2 * x, y: tip.y - 2 * y)
                path.move(to: CGPoint(x: base.x - 2 * y, y: base.y + 2 * x))
                path.addLine(to: tip)
                path.addLine(to: CGPoint(x: base.x + 2 * y, y: base.y - 2 * x))
            }
        }
        .stroke(ink, lineWidth: 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged(updateDrag)
            .onEnded { value in
                updateDrag(value)
                dragWidths = nil
            }
    }

    private func updateDrag(_ value: DragGesture.Value) {
        let previous = dragWidths ?? (start: width, last: width)
        let next = AnnotationStyle.draggedWidth(from: previous.start, horizontal: value.translation.width,
                                                vertical: value.translation.height, in: range)
        dragWidths = (start: previous.start, last: next)
        if next != previous.last { width = next }
        updateHover(at: value.location)
    }

    private func updateHover(at location: CGPoint) {
        let radius = diameter / 2
        hovering = hypot(location.x - radius, location.y - radius) <= radius
    }
}
