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
    /// Whether shift was down when the press started; see the split in `drag`.
    @State private var shifted = false
    /// How close a divider has to come to a stop before it is pulled onto it.
    private static let magnetPoints: CGFloat = 12
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
            .overlay {
                if editable {
                    RightClickCatcher { splitZone(at: $0, in: geo.size) }
                }
            }
        }
    }

    // MARK: - Editing

    private func drag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !began {
                    began = true
                    lastValid = nil
                    shifted = NSEvent.modifierFlags.contains(.shift)
                    interaction = begin(at: value.startLocation, in: size)
                }
                guard let interaction, case .resize(let items) = interaction else { return }
                let delta = pull(items, translation: value.translation, size: size)
                let candidate = apply(items, dx: delta.dx, dy: delta.dy)
                if !ZoneGeometry.overlaps(candidate, at: items.map(\.index)) {
                    lastValid = candidate
                }
                liveZones = lastValid ?? zones
            }
            .onEnded { value in
                defer { began = false; interaction = nil; liveZones = nil; lastValid = nil }
                switch interaction {
                case .resize:
                    // What was drawn is what is kept: the magnet has already
                    // done its pulling while the divider was under the pointer.
                    guard let result = lastValid else { return }
                    onChange?(result)
                case .split(let index, let point):
                    let moved = abs(value.translation.width) > 4 || abs(value.translation.height) > 4
                    guard !moved else { return }
                    // Read at mouse-down as well as now: a modifier let go of
                    // early, or taken up late, still means what it looked like.
                    let vertical = shifted || NSEvent.modifierFlags.contains(.shift)
                    split(index, at: point, vertical: vertical, in: size)
                case nil:
                    break
                }
            }
    }

    /// How far the drag actually moves the divider: the pointer's translation,
    /// then pulled onto a stop or a neighbouring edge if one is close. Both
    /// sides of a divider are moved by the same amount, so they cannot come
    /// apart however hard the magnet pulls.
    private func pull(_ items: [(index: Int, origin: ZoneRect, edges: Edges)],
                      translation: CGSize, size: CGSize) -> (dx: Double, dy: Double) {
        var dx = Double(translation.width / size.width)
        var dy = Double(translation.height / size.height)
        let moved = Set(items.map(\.index))
        if let anchor = items.compactMap(horizontalAnchor).first {
            dx = ZoneGeometry.magnet(anchor + dx, to: edges(on: .horizontal, excluding: moved),
                                     tolerance: Double(Self.magnetPoints / size.width)) - anchor
        }
        if let anchor = items.compactMap(verticalAnchor).first {
            dy = ZoneGeometry.magnet(anchor + dy, to: edges(on: .vertical, excluding: moved),
                                     tolerance: Double(Self.magnetPoints / size.height)) - anchor
        }
        return (dx, dy)
    }

    private func horizontalAnchor(_ item: (index: Int, origin: ZoneRect, edges: Edges)) -> Double? {
        if item.edges.contains(.left) { return item.origin.x }
        if item.edges.contains(.right) { return item.origin.x + item.origin.w }
        return nil
    }

    private func verticalAnchor(_ item: (index: Int, origin: ZoneRect, edges: Edges)) -> Double? {
        if item.edges.contains(.top) { return item.origin.y }
        if item.edges.contains(.bottom) { return item.origin.y + item.origin.h }
        return nil
    }

    private enum Axis { case horizontal, vertical }

    /// The edges the zones standing still already keep, so a divider lines up
    /// with the column above it instead of landing a few points off.
    private func edges(on axis: Axis, excluding moved: Set<Int>) -> [Double] {
        zones.enumerated().filter { !moved.contains($0.offset) }.flatMap { _, z in
            axis == .horizontal ? [z.x, z.x + z.w] : [z.y, z.y + z.h]
        }
    }

    /// The right button splits the other way from the left one. Nothing else in
    /// the editor uses it, and a button is easier to hold than a modifier: the
    /// ⇧-click that used to be the only way to cut a zone left and right is
    /// still there, but it is no longer the only way.
    private func splitZone(at point: CGPoint, in size: CGSize) {
        guard let index = zoneIndex(at: point, in: size) else { return }
        split(index, at: point, vertical: true, in: size)
    }

    /// The smallest zone the point is inside, which is the one a click means
    /// when zones abut: the outer one is not the one being aimed at.
    private func zoneIndex(at point: CGPoint, in size: CGSize) -> Int? {
        let px = Double(point.x / size.width)
        let py = Double(point.y / size.height)
        var hit: (index: Int, area: Double)?
        for (index, z) in zones.enumerated()
        where px >= z.x && px <= z.x + z.w && py >= z.y && py <= z.y + z.h {
            let area = z.w * z.h
            if hit == nil || area < hit!.area { hit = (index, area) }
        }
        return hit?.index
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
        }
        if !resizeItems.isEmpty { return .resize(items: resizeItems) }
        if let index = zoneIndex(at: point, in: size) { return .split(index: index, point: point) }
        return nil
    }

    private func apply(_ items: [(index: Int, origin: ZoneRect, edges: Edges)],
                       dx: Double, dy: Double) -> [ZoneRect] {
        var result = zones
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
