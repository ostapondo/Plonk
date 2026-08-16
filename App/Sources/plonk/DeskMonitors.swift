import SwiftUI

// A workspace drawn as the desk it rebuilds: one bar per monitor, each window
// in its place inside it, coloured by the zone it lands in.
//
// The zone number is not stored — a workspace saves frames — so it is read back
// off the geometry against whatever set that screen is running now. A window
// that matches no zone stays grey: the picture is allowed to say "not a zone",
// and is not allowed to make a number up.

struct DeskMonitors: View {
    @ObservedObject var model: AppModel
    let items: [WorkspaceItem]
    @Environment(\.colorScheme) private var scheme

    /// The monitors this desk touches, in display order. A window saved without
    /// a screen belongs to the main one, which is where it will be put back.
    private var screens: [Int] {
        Set(items.map { $0.screen ?? 0 }).sorted()
    }

    /// An unassigned screen falls back to the default set; an empty assignment
    /// is edge snapping, which has no zones to match against.
    private func zones(on screen: Int) -> [ZoneRect] {
        let name = model.screenAssignments[screen] ?? BuiltinZoneSets.defaultName
        guard !name.isEmpty else { return [] }
        return model.zoneSets[name] ?? []
    }

    var body: some View {
        HStack(spacing: 5) {
            if screens.isEmpty {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            }
            ForEach(screens, id: \.self) { screen in
                monitor(screen)
            }
        }
    }

    private func monitor(_ screen: Int) -> some View {
        let windows = items.filter { ($0.screen ?? 0) == screen }
        let set = zones(on: screen)
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                ForEach(Array(windows.enumerated()), id: \.offset) { _, window in
                    tile(window, set: set, in: geo.size)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tile(_ window: WorkspaceItem, set: [ZoneRect], in size: CGSize) -> some View {
        let frame = FracRect(window.x, window.y, window.w, window.h)
        let zone = ZoneGeometry.nearest(to: frame, in: set)
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(zone.map { AnyShapeStyle(Ink.zoneGradient($0)) }
                  ?? AnyShapeStyle(Color.primary.opacity(0.18)))
            .frame(width: max(window.w * size.width - 3, 2),
                   height: max(window.h * size.height - 3, 2))
            .offset(x: window.x * size.width + 1.5, y: window.y * size.height + 1.5)
    }
}
