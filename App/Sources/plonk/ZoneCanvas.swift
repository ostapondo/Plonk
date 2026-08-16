import SwiftUI

// Draws a zone set, and in editable mode handles splitting, resizing and
// deleting. Zones cannot overlap: an edit that would overlap is dropped and
// the last valid arrangement stays on screen.

struct ZoneCanvas: View {
    let zones: [ZoneRect]
    var editable = false
    var fullscreen = false
    /// Ringed while the keyboard is editing it.
    var selected: Int?
    var onChange: (([ZoneRect]) -> Void)?

    private struct Edges: OptionSet {
        let rawValue: Int
        static let left = Edges(rawValue: 1)
        static let right = Edges(rawValue: 2)
        static let top = Edges(rawValue: 4)
        static let bottom = Edges(rawValue: 8)
    }

    private enum Interaction {
        // A grabbed border can belong to several zones; they all resize
        // together, which is what makes it behave like a divider.
        case resize(items: [(index: Int, origin: ZoneRect, edges: Edges)])
        // A press inside a zone splits it on release, unless it turned into a drag.
        case split(index: Int, point: CGPoint)
    }

    @State private var interaction: Interaction?
    @State private var began = false
    @State private var liveZones: [ZoneRect]?
    @State private var lastValid: [ZoneRect]?

    var body: some View {
        GeometryReader { geo in
            let shown = liveZones ?? zones
            ZStack(alignment: .topLeading) {
                if !fullscreen {
                    RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.12))
                    RoundedRectangle(cornerRadius: 6).strokeBorder(Color.gray.opacity(0.35))
                }
                ForEach(Array(shown.enumerated()), id: \.offset) { index, z in
                    zoneView(z, index: index, shown: shown, size: geo.size)
                        .frame(width: max(z.w * geo.size.width - 4, 8), height: max(z.h * geo.size.height - 4, 8))
                        .offset(x: z.x * geo.size.width + 2, y: z.y * geo.size.height + 2)
                        // Sized and placed by the modifiers above, so the ring
                        // only has to fill what it is drawn over.
                        .overlay {
                            if index == selected {
                                RoundedRectangle(cornerRadius: fullscreen ? 8 : 3)
                                    .strokeBorder(Color.accentColor, lineWidth: 3)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                if editable && fullscreen {
                    ForEach(Array(dividerHandles(in: shown, size: geo.size).enumerated()), id: \.offset) { _, handle in
                        dividerHandle(handle)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(editable ? drag(in: geo.size) : nil)
        }
    }

    private func zoneView(_ z: ZoneRect, index: Int, shown: [ZoneRect], size: CGSize) -> some View {
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

    private func dividerHandle(_ handle: (point: CGPoint, vertical: Bool)) -> some View {
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

    private func dividerHandles(in shown: [ZoneRect], size: CGSize) -> [(point: CGPoint, vertical: Bool)] {
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

    // MARK: - Editing

    private func drag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !began {
                    began = true
                    lastValid = nil
                    interaction = begin(at: value.startLocation, in: size)
                }
                guard let interaction, case .resize = interaction else { return }
                let candidate = apply(interaction, value: value, size: size)
                if !ZoneGeometry.overlaps(candidate, at: changedIndices(interaction)) {
                    lastValid = candidate
                }
                liveZones = lastValid ?? zones
            }
            .onEnded { value in
                defer { began = false; interaction = nil; liveZones = nil; lastValid = nil }
                switch interaction {
                case .resize(let items):
                    guard let result = lastValid else { return }
                    onChange?(snapped(result, at: items.map(\.index)))
                case .split(let index, let point):
                    let moved = abs(value.translation.width) > 4 || abs(value.translation.height) > 4
                    guard !moved else { return }
                    split(index, at: point, vertical: NSEvent.modifierFlags.contains(.shift), in: size)
                case nil:
                    break
                }
            }
    }

    /// Snapping can push a zone into its neighbor; keep the unsnapped result then.
    private func snapped(_ zones: [ZoneRect], at indices: [Int]) -> [ZoneRect] {
        var candidate = zones
        for index in indices where candidate.indices.contains(index) {
            candidate[index] = ZoneGeometry.snap(candidate[index])
        }
        return ZoneGeometry.overlaps(candidate, at: indices) ? zones : candidate
    }

    private func split(_ index: Int, at point: CGPoint, vertical: Bool, in size: CGSize) {
        let fraction = vertical ? Double(point.x / size.width) : Double(point.y / size.height)
        if let result = ZoneGeometry.split(zones, at: index, fraction: fraction, vertical: vertical) {
            onChange?(result)
        }
    }

    private func changedIndices(_ interaction: Interaction) -> [Int] {
        switch interaction {
        case .resize(let items): return items.map(\.index)
        case .split: return []
        }
    }

    private func begin(at point: CGPoint, in size: CGSize) -> Interaction? {
        let px = point.x / size.width
        let py = point.y / size.height
        let bandX = 12 / size.width
        let bandY = 12 / size.height

        var resizeItems: [(index: Int, origin: ZoneRect, edges: Edges)] = []
        var insideHit: (index: Int, area: Double)?
        for (index, z) in zones.enumerated() {
            if px >= z.x - bandX, px <= z.x + z.w + bandX, py >= z.y - bandY, py <= z.y + z.h + bandY {
                var edges: Edges = []
                if abs(px - z.x) <= bandX { edges.insert(.left) }
                if abs(px - (z.x + z.w)) <= bandX { edges.insert(.right) }
                if abs(py - z.y) <= bandY { edges.insert(.top) }
                if abs(py - (z.y + z.h)) <= bandY { edges.insert(.bottom) }
                // The screen frame is not a divider, so a grab that only caught
                // the outer edge still counts as a click inside the zone.
                if z.x < 0.001 { edges.remove(.left) }
                if z.x + z.w > 0.999 { edges.remove(.right) }
                if z.y < 0.001 { edges.remove(.top) }
                if z.y + z.h > 0.999 { edges.remove(.bottom) }
                if !edges.isEmpty { resizeItems.append((index, z, edges)) }
            }
            if px >= z.x, px <= z.x + z.w, py >= z.y, py <= z.y + z.h {
                let area = z.w * z.h
                if insideHit == nil || area < insideHit!.area { insideHit = (index, area) }
            }
        }
        if !resizeItems.isEmpty { return .resize(items: resizeItems) }
        if let insideHit { return .split(index: insideHit.index, point: point) }
        return nil
    }

    private func apply(_ interaction: Interaction, value: DragGesture.Value, size: CGSize) -> [ZoneRect] {
        var result = zones
        guard case .resize(let items) = interaction else { return result }
        let dx = value.translation.width / size.width
        let dy = value.translation.height / size.height
        for (index, origin, edges) in items {
            guard result.indices.contains(index) else { continue }
            var z = origin
            if edges.contains(.left) {
                let nx = min(max(origin.x + dx, 0), origin.x + origin.w - ZoneGeometry.minSide)
                z.w = origin.x + origin.w - nx
                z.x = nx
            }
            if edges.contains(.right) {
                z.w = min(max(origin.w + dx, ZoneGeometry.minSide), 1 - origin.x)
            }
            if edges.contains(.top) {
                let ny = min(max(origin.y + dy, 0), origin.y + origin.h - ZoneGeometry.minSide)
                z.h = origin.y + origin.h - ny
                z.y = ny
            }
            if edges.contains(.bottom) {
                z.h = min(max(origin.h + dy, ZoneGeometry.minSide), 1 - origin.y)
            }
            result[index] = z
        }
        return result
    }
}
