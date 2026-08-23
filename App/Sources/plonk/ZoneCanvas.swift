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
    /// Fullscreen only: the set's gap in points, drawn as the inset a window
    /// gets, so the editor shows the layout the way it will land. Nil keeps
    /// the hairline gutter the thumbnails use.
    var gap: Double?
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
                let inset = gap.map { CGFloat($0) } ?? 2
                ForEach(Array(shown.enumerated()), id: \.offset) { index, z in
                    zoneView(z, index: index, shown: shown, size: geo.size)
                        .frame(width: max(z.w * geo.size.width - 2 * inset, 8),
                               height: max(z.h * geo.size.height - 2 * inset, 8))
                        .offset(x: z.x * geo.size.width + inset, y: z.y * geo.size.height + inset)
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

    // MARK: - Editing

    private func drag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !began {
                    began = true
                    lastValid = nil
                    interaction = begin(at: value.startLocation, in: size)
                }
                guard let interaction, case .resize(let items) = interaction else { return }
                let candidate = apply(items, value: value, size: size)
                if !ZoneGeometry.overlaps(candidate, at: items.map(\.index)) {
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

    private func apply(_ items: [(index: Int, origin: ZoneRect, edges: Edges)],
                       value: DragGesture.Value, size: CGSize) -> [ZoneRect] {
        var result = zones
        let dx = value.translation.width / size.width
        let dy = value.translation.height / size.height
        for (index, origin, edges) in items {
            guard result.indices.contains(index) else { continue }
            var z = origin
            if edges.contains(.left) {
                let nx = (origin.x + dx).clamped(to: 0...(origin.x + origin.w - ZoneGeometry.minSide))
                z.w = origin.x + origin.w - nx
                z.x = nx
            }
            if edges.contains(.right) {
                z.w = (origin.w + dx).clamped(to: ZoneGeometry.minSide...(1 - origin.x))
            }
            if edges.contains(.top) {
                let ny = (origin.y + dy).clamped(to: 0...(origin.y + origin.h - ZoneGeometry.minSide))
                z.h = origin.y + origin.h - ny
                z.y = ny
            }
            if edges.contains(.bottom) {
                z.h = (origin.h + dy).clamped(to: ZoneGeometry.minSide...(1 - origin.y))
            }
            result[index] = z
        }
        return result
    }
}
