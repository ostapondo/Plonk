import SwiftUI

// The top of the Zones page: which set is on which screen, drawn rather than
// picked from a menu.
//
// The old page opened with a pop-up per screen listing set names. A zone set is
// a shape; naming it and hiding the shape behind a menu made the one thing the
// page is about invisible, and the editor that produces the shapes was a window
// somewhere else entirely.

struct ZoneSetCanvas: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    @State private var chosen = 0

    /// Clamped on read, because a display can go away while this page is open
    /// and a stale index writes an assignment for a monitor that is not there.
    private var screen: Int { min(max(chosen, 0), max(model.screenCount - 1, 0)) }

    /// The assignment as the page thinks of it: a set name, or nil for edge
    /// snapping. An unassigned screen falls back to the default set.
    private var assigned: String? {
        guard let name = model.screenAssignments[screen] else { return BuiltinZoneSets.defaultName }
        return name.isEmpty ? nil : name
    }

    private var zones: [ZoneRect] {
        guard let assigned else { return [] }
        return model.zoneSets[assigned] ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            tabs
            ZonePreview(zones: zones, accent: model.accent)
                .frame(height: 250)
            actions
        }
        .padding(12)
        .card()
    }

    // MARK: - Tabs

    private var tabs: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.zoneSetNames, id: \.self) { name in
                        tab(name, selected: assigned == name, icon: "square.grid.2x2") {
                            model.actions?.assignZoneSet(name, toScreen: screen)
                        }
                    }
                    tab(String(localized: .zoneSetEdgeSnapping), selected: assigned == nil,
                        icon: "rectangle.split.2x1") {
                        model.actions?.assignZoneSet("", toScreen: screen)
                    }
                    tab(String(localized: .zoneSetNewSet), selected: false, icon: "plus", dashed: true) {
                        model.actions?.editZoneSet(nextSetName, seed: [ZoneRect(0, 0, 1, 1)],
                                                   onScreen: screen)
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

    private func tab(_ title: String, selected: Bool, icon: String, dashed: Bool = false,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.system(size: 11.5)).lineLimit(1)
            }
            .foregroundStyle(selected ? Color.white : Color.secondary)
            .padding(.horizontal, 11)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? AnyShapeStyle(Ink.gradient(model.accent))
                                   : AnyShapeStyle(Ink.raised(scheme)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Ink.stroke(scheme),
                                  style: StrokeStyle(lineWidth: 1, dash: dashed ? [3, 3] : []))
                    .opacity(selected ? 0 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }

    /// "Set 2", "Set 3" — the first one nobody has taken.
    private var nextSetName: String {
        var index = model.zoneSetNames.count + 1
        while model.zoneSetNames.contains("Set \(index)") { index += 1 }
        return "Set \(index)"
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 9) {
            Text(assigned == nil
                 ? String(localized: .zoneSetEdgeHint)
                 : String(localized: .zoneSetZoneHint))
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 8)
            if let assigned {
                Button(.zoneSetPreview) { model.actions?.togglePreview(zoneSet: assigned, onScreen: screen) }
                    .help(String(localized: .zoneSetPreviewHelp))
                Button(.zoneSetDuplicate) {
                    model.actions?.editZoneSet(nextSetName, seed: zones, onScreen: screen)
                }
                Button(.zoneSetEdit) { model.actions?.editZoneSet(assigned, seed: nil, onScreen: screen) }
                    .buttonStyle(.borderedProminent)
            }
            Button(.zoneSetManage) { model.actions?.openZonePicker() }
                .help(String(localized: .zoneSetManageHelp))
        }
        .controlSize(.small)
    }
}
