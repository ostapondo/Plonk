import SwiftUI

// The top of the Zones page: which set is on which screen, drawn rather than
// picked from a menu.
//
// The old page opened with a pop-up per screen listing set names. A zone set is
// a shape; naming it and hiding the shape behind a menu made the one thing the
// page is about invisible, and the editor that produces the shapes was a window
// somewhere else entirely.
//
// The set names itself in display weight, says what it is under that, and the
// sets to switch to are pills — the shape of a segmented choice, not of a list.

struct ZoneSetCanvas: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    @State private var chosen = 0

    /// Clamped on read, because a display can go away while this page is open
    /// and a stale index writes an assignment for a monitor that is not there.
    private var screen: Int { chosen.clamped(to: 0...max(model.screenCount - 1, 0)) }

    /// The assignment as the page thinks of it: a set name, or nil for edge
    /// snapping. An unassigned screen falls back to the default set.
    private var assigned: String? {
        let name = model.assignedZoneSet(onScreen: screen)
        return name.isEmpty ? nil : name
    }

    private var zones: [ZoneRect] { model.zones(onScreen: screen) }
    private var size: String { model.screenDescription(screen) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            tabs
            canvas
            hint
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(assigned ?? String(localized: .zoneSetEdgeSnapping))
                    .font(.system(size: 26, weight: .heavy))
                    .kerning(-0.7)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            actions
        }
    }

    /// What this screen is running, in the order it is asked about: how big it
    /// is, how many zones are on it, and how much air each window keeps.
    private var subtitle: String {
        guard assigned != nil else {
            return String(localized: .zoneSetScreenWithSize(screen + 1, size))
        }
        return String(localized: .zoneSetSummary(screen + 1, size,
                                                 String(localized: .zoneSetZoneCount(zones.count)),
                                                 Int(model.config.zoneGap(forSet: assigned))))
    }

    private var actions: some View {
        HStack(spacing: 7) {
            if let assigned {
                Button(String(localized: .zoneSetPreview)) {
                    model.actions?.togglePreview(zoneSet: assigned, onScreen: screen)
                }
                .help(String(localized: .zoneSetPreviewHelp))
                Button(String(localized: .zoneSetDuplicate)) {
                    model.actions?.editZoneSet(model.freeZoneSetName(base: assigned + " copy"),
                                               seed: zones, onScreen: screen)
                }
            }
            Button(String(localized: .zoneSetManage)) { model.actions?.openZonePicker() }
                .help(String(localized: .zoneSetManageHelp))
            if let assigned {
                Button(String(localized: .zoneSetEdit)) {
                    model.actions?.editZoneSet(assigned, seed: nil, onScreen: screen)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .controlSize(.small)
    }

    // MARK: - Tabs

    private var tabs: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(model.zoneSetNames, id: \.self) { name in
                        tab(name, selected: assigned == name) {
                            model.actions?.assignZoneSet(name, toScreen: screen)
                        }
                    }
                    tab(String(localized: .zoneSetEdgeSnapping), selected: assigned == nil) {
                        model.actions?.assignZoneSet("", toScreen: screen)
                    }
                    tab(String(localized: .zoneSetNewSet), selected: false, plus: true) {
                        model.actions?.editZoneSet(model.freeZoneSetName(base: "Set"),
                                                   seed: [ZoneRect(0, 0, 1, 1)], onScreen: screen)
                    }
                }
                .padding(.vertical, 1)
            }
            if model.screenCount > 1 {
                Picker("", selection: $chosen) {
                    ForEach(0..<model.screenCount, id: \.self) { index in
                        Text(.zoneSetScreen(index + 1)).tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    /// The selected pill is ink rather than the accent: the accent is already
    /// the selected row in the sidebar, and two accents on one screen stop
    /// meaning "this one".
    private func tab(_ title: String, selected: Bool, plus: Bool = false,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if plus { Image(systemName: "plus").font(.system(size: 10, weight: .bold)) }
                Text(title).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(selected ? AnyShapeStyle(Ink.page(scheme)) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 12)
            .frame(height: 25)
            .background(Capsule().fill(selected ? AnyShapeStyle(Color.primary.opacity(0.92))
                                                : AnyShapeStyle(Ink.capFill)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(title)
    }

    // MARK: - Canvas

    private var canvas: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(Array(zones.enumerated()), id: \.offset) { index, zone in
                    tile(index: index, zone: zone, in: geo.size)
                }
                if zones.isEmpty {
                    Text(.homeEdgeSnapping)
                        .font(.system(size: 12.5))
                        .muted()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(height: 288)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.primary.opacity(0.05)))
    }

    private func tile(index: Int, zone: ZoneRect, in size: CGSize) -> some View {
        // Colour is the zone number, and the fraction printed on it is the same
        // number an agent sends over MCP, so the picture and the API agree.
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Ink.zoneGradient(index))
            .overlay(alignment: .bottomLeading) {
                Text("\(index + 1)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Ink.zoneInk(index))
                    .padding(9)
            }
            .overlay(alignment: .topTrailing) {
                Text(Self.fraction(zone.w, zone.h))
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Ink.zoneInk(index).opacity(0.85))
                    .padding(9)
            }
            .frame(width: max(zone.w * size.width - 5, 1),
                   height: max(zone.h * size.height - 5, 1))
            .offset(x: zone.x * size.width + 2.5, y: zone.y * size.height + 2.5)
    }

    /// "0.22 × 0.5". Two decimals, and no trailing zeros to read past.
    static func fraction(_ width: Double, _ height: Double) -> String {
        func trim(_ value: Double) -> String {
            let text = String(format: "%.2f", value)
            guard text.contains(".") else { return text }
            var trimmed = text
            while trimmed.hasSuffix("0") { trimmed.removeLast() }
            if trimmed.hasSuffix(".") { trimmed.removeLast() }
            return trimmed
        }
        return "\(trim(width)) × \(trim(height))"
    }

    private var hint: some View {
        Text(assigned == nil ? .zoneSetEdgeHint : .zoneSetZoneHint)
            .font(.caption)
            .muted()
    }
}
