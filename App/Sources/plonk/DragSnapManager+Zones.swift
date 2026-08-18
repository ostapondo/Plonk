import AppKit

// Which zone the cursor is over, and what a drop there should cover.
//
// Three answers, in order: the zone under the pointer; that zone spanned with
// the one the drag started on, while the span modifier is held; and the pair
// straddled when the cursor sits on the seam between two. Edge snapping is the
// fallback for a screen with no zone set, and lives here for the same reason.
//
// The drag state these read is not private only because the type is split
// across two files; nothing outside DragSnapManager should touch it.

extension DragSnapManager {
    func updateZone(_ flags: NSEvent.ModifierFlags) {
        let modifierHeld = flags.contains(modifierFlag)
        let spanHeld = flags.contains(Self.spanFlag)
        if !spanHeld { spanAnchor = nil }

        let p = NSEvent.mouseLocation
        guard let index = NSScreen.screens.firstIndex(where: { $0.frame.insetBy(dx: -1, dy: -1).contains(p) }) else {
            currentZone = nil
            hideAll()
            return
        }
        let screen = NSScreen.screens[index]
        let zones = zonesForScreen?(index) ?? []

        if !zones.isEmpty {
            // The modifier inverts the activation mode, so the other behavior stays reachable.
            guard modifierHeld == requireModifier else {
                currentZone = nil
                hideAll()
                return
            }
            let v = screen.visibleFrame
            let hovered = zoneIndex(at: p, in: zones, visible: v)
            let spanned = spanHeld
                ? span(from: hovered, on: index, in: zones)
                : straddle(from: hovered, at: p, in: zones, visible: v)
            overlay(for: index).show(zones: zones,
                                     highlighted: spanned?.indices ?? Set(hovered.map { [$0] } ?? []),
                                     visible: v, appearance: look)
            showOthers(except: index)
            if let spanned {
                currentZone = (index, spanned.frac)
            } else {
                currentZone = hovered.map { (index, zones[$0].frac) }
            }
        } else if let frac = edgeZone(at: p, on: screen) {
            overlay(for: index).show(zones: [ZoneRect(frac.x, frac.y, frac.w, frac.h)], highlighted: [0],
                                     visible: screen.visibleFrame, appearance: look)
            showOthers(except: index)
            currentZone = (index, frac)
        } else {
            currentZone = nil
            hideAll()
        }
    }

    /// The rect covering the anchor zone and the hovered one, once Command has
    /// been held over two of them. The first hovered zone becomes the anchor
    /// and spans nothing on its own, so tapping Command never changes a drop.
    func span(from hovered: Int?, on screenIndex: Int,
                      in zones: [ZoneRect]) -> (frac: FracRect, indices: Set<Int>)? {
        guard let hovered else { return nil }
        guard let anchor = spanAnchor, anchor.screenIndex == screenIndex,
              zones.indices.contains(anchor.zoneIndex) else {
            spanAnchor = (screenIndex, hovered)
            return nil
        }
        guard anchor.zoneIndex != hovered else { return nil }
        let frac = ZoneGeometry.union(zones[anchor.zoneIndex], zones[hovered])
        return (frac, ZoneGeometry.covered(zones, by: frac))
    }

    /// The pair a cursor near a shared edge takes, with no modifier held —
    /// PowerToys' other way of covering two zones at once. The tolerance is in
    /// points, converted per axis because a fraction of a wide screen is not
    /// the same distance as a fraction of a tall one.
    func straddle(from hovered: Int?, at p: NSPoint, in zones: [ZoneRect],
                          visible v: NSRect) -> (frac: FracRect, indices: Set<Int>)? {
        guard edgeSpanPoints > 0, let hovered, v.width > 0, v.height > 0 else { return nil }
        let fx = Double((p.x - v.minX) / v.width)
        let fy = Double((v.maxY - p.y) / v.height)
        guard let other = ZoneGeometry.neighbour(zones, of: hovered, atX: fx, y: fy,
                                                 toleranceX: edgeSpanPoints / Double(v.width),
                                                 toleranceY: edgeSpanPoints / Double(v.height)) else { return nil }
        let frac = ZoneGeometry.union(zones[hovered], zones[other])
        return (frac, ZoneGeometry.covered(zones, by: frac))
    }

    /// Draws the other screens' zones without highlighting anything, or hides
    /// them, depending on the setting.
    func showOthers(except screenIndex: Int) {
        guard showOnAllMonitors else {
            hideAll(except: screenIndex)
            return
        }
        for (index, screen) in NSScreen.screens.enumerated() where index != screenIndex {
            let zones = zonesForScreen?(index) ?? []
            guard !zones.isEmpty else {
                overlays[index]?.hide()
                continue
            }
            overlay(for: index).show(zones: zones, highlighted: [], visible: screen.visibleFrame,
                                     appearance: look)
        }
    }

    /// Smallest zone under the cursor, so overlapping sets stay usable.
    func zoneIndex(at p: NSPoint, in zones: [ZoneRect], visible v: NSRect) -> Int? {
        let fx = (p.x - v.minX) / v.width
        let fyTop = (v.maxY - p.y) / v.height
        var hovered: Int?
        var smallest = Double.infinity
        for (i, z) in zones.enumerated()
        where fx >= z.x && fx <= z.x + z.w && fyTop >= z.y && fyTop <= z.y + z.h {
            let area = z.w * z.h
            if area < smallest { smallest = area; hovered = i }
        }
        return hovered
    }

    func edgeZone(at p: NSPoint, on screen: NSScreen) -> FracRect? {
        let f = screen.frame
        let margin: CGFloat = 24
        let fx = (p.x - f.minX) / f.width
        let fyTop = (f.maxY - p.y) / f.height

        if p.x - f.minX < margin {
            if fyTop < 0.25 { return Preset.topLeft.frac }
            if fyTop > 0.75 { return Preset.bottomLeft.frac }
            return Preset.leftHalf.frac
        }
        if f.maxX - p.x < margin {
            if fyTop < 0.25 { return Preset.topRight.frac }
            if fyTop > 0.75 { return Preset.bottomRight.frac }
            return Preset.rightHalf.frac
        }
        if f.maxY - p.y < margin {
            if fx < 0.25 { return Preset.topLeft.frac }
            if fx > 0.75 { return Preset.topRight.frac }
            return Preset.maximize.frac
        }
        if p.y - f.minY < margin {
            if fx < 0.25 { return Preset.bottomLeft.frac }
            if fx > 0.75 { return Preset.bottomRight.frac }
            return Preset.bottomHalf.frac
        }
        return nil
    }
}
