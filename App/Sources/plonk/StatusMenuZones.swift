import SwiftUI

// The head of the menu bar dropdown: the set that is live on the main screen,
// drawn, with every rectangle clickable.
//
// That makes the menu a fourth way to place a window, beside the drag, the key
// and the sentence — and the only one that needs neither a shortcut learned nor
// a window in your hand. The colours are the zone numbers, so what is clicked
// here is recognisably the same rectangle the overlay lights up mid-drag.

struct StatusMenuZones: View {
    let zones: [ZoneRect]
    /// "2 displays · Priority", built where the config is.
    let summary: String
    let snap: (Int) -> Void

    static let width: CGFloat = 300
    static let height: CGFloat = 148

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(.appName).font(.system(size: 13, weight: .bold))
                Spacer(minLength: 6)
                Text(summary)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if zones.isEmpty {
                Text(.zoneSetEdgeHint)
                    .font(.system(size: 11.5))
                    .muted()
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(zones.enumerated()), id: \.offset) { index, zone in
                            tile(index: index, zone: zone, in: geo.size)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .frame(width: Self.width, height: Self.height)
    }

    private func tile(index: Int, zone: ZoneRect, in size: CGSize) -> some View {
        Button {
            // Zones are numbered from one everywhere a person sees them, and
            // that is the number snap(toZone:) takes.
            snap(index + 1)
        } label: {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Ink.zoneGradient(index))
                .overlay(alignment: .bottomLeading) {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Ink.zoneInk(index))
                        .padding(6)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(String(localized: .menuSendToZone(index + 1)))
        .frame(width: max(zone.w * size.width - 4, 2),
               height: max(zone.h * size.height - 4, 2))
        .offset(x: zone.x * size.width + 2, y: zone.y * size.height + 2)
    }
}
