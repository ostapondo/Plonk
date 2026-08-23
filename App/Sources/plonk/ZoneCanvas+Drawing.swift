import SwiftUI

// What the canvas looks like: a zone, the round handle on a divider, and where
// those handles go. Split out from ZoneCanvas so the editing half of the same
// view keeps its file under the length limit; nothing here decides anything.

extension ZoneCanvas {
    func zoneView(_ z: ZoneRect, index: Int, shown: [ZoneRect], size: CGSize) -> some View {
        // Colour is the zone number, so this rectangle looks the same here, in
        // the drag overlay and in the menu bar. The accent stays on the chrome:
        // the selection ring, the delete button and the divider handles.
        let hue = Ink.zone(index)
        return ZStack {
            RoundedRectangle(cornerRadius: fullscreen ? 8 : 3)
                .fill(hue.opacity(fullscreen ? 0.22 : 0.16))
            RoundedRectangle(cornerRadius: fullscreen ? 8 : 3)
                .strokeBorder(hue.opacity(0.75), lineWidth: fullscreen ? 2 : 1)
            if fullscreen {
                VStack(spacing: 2) {
                    Text("\(index + 1)")
                        .font(.system(size: 40, weight: .bold))
                    Text("\(Int(z.w * size.width)) × \(Int(z.h * size.height))")
                        .font(.callout.monospacedDigit())
                }
                .foregroundStyle(hue)
            }
        }
        .overlay(alignment: .topTrailing) {
            if editable && fullscreen && shown.count > 1 {
                Button {
                    onChange?(ZoneGeometry.removeAndHeal(shown, at: index))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, Color.accentColor)
                }
                .buttonStyle(.borderless)
                .padding(8)
            }
        }
    }

    func dividerHandle(_ handle: (point: CGPoint, vertical: Bool)) -> some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 26, height: 26)
            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
            .overlay(
                Image(systemName: handle.vertical ? "pause.fill" : "equal")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            )
            .position(handle.point)
            .allowsHitTesting(false)
    }

    func dividerHandles(in shown: [ZoneRect], size: CGSize) -> [(point: CGPoint, vertical: Bool)] {
        var handles: [(point: CGPoint, vertical: Bool)] = []
        for (i, a) in shown.enumerated() {
            for (j, b) in shown.enumerated() where j != i {
                if abs((a.x + a.w) - b.x) < 0.001 {
                    let y0 = max(a.y, b.y)
                    let y1 = min(a.y + a.h, b.y + b.h)
                    if y1 - y0 > 0.02 {
                        handles.append((CGPoint(x: (a.x + a.w) * size.width, y: (y0 + y1) / 2 * size.height), true))
                    }
                }
                if abs((a.y + a.h) - b.y) < 0.001 {
                    let x0 = max(a.x, b.x)
                    let x1 = min(a.x + a.w, b.x + b.w)
                    if x1 - x0 > 0.02 {
                        handles.append((CGPoint(x: (x0 + x1) / 2 * size.width, y: (a.y + a.h) * size.height), false))
                    }
                }
            }
        }
        return handles
    }
}
