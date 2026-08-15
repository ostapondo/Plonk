import SwiftUI

// Monitor bar on top, template and custom layout cards below. Clicking a card
// assigns it to the selected monitor; the pencil opens fullscreen editing,
// duplicating templates first so built-ins stay intact.

struct ZonePickerView: View {
    @ObservedObject var model: AppModel
    @State private var selectedScreen = 0

    private var assignedName: String {
        model.screenAssignments[selectedScreen].map { $0.isEmpty ? "edge" : $0 } ?? BuiltinZoneSets.defaultName
    }

    private var builtinNames: [String] {
        model.zoneSetNames.filter { !model.customZoneSetNames.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            monitorBar
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.gray.opacity(0.06))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(.zoneSetTemplates).font(.title3.bold())
                    cardGrid(edgeCard: true, names: builtinNames)
                    Text(.zoneSetCustom).font(.title3.bold()).padding(.top, 8)
                    if model.customZoneSetNames.isEmpty {
                        emptyState
                    } else {
                        cardGrid(edgeCard: false, names: model.customZoneSetNames)
                    }
                }
                .padding(16)
            }
            Divider()
            HStack {
                Spacer()
                Button(action: createNewLayout) {
                    Label(String(localized: .zoneSetCreateNew), systemImage: "plus")
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(minWidth: 740, minHeight: 540)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "rectangle.split.2x1")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(.zoneSetEmptyState)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var monitorBar: some View {
        HStack(spacing: 12) {
            ForEach(0..<model.screenCount, id: \.self) { screen in
                Button {
                    selectedScreen = screen
                } label: {
                    VStack(spacing: 2) {
                        Text("\(screen + 1)").font(.title2.bold())
                        Text(model.screenDescriptions.indices.contains(screen) ? model.screenDescriptions[screen] : "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 110, height: 62)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.08)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(selectedScreen == screen ? Color.accentColor : Color.gray.opacity(0.3),
                                          lineWidth: selectedScreen == screen ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cardGrid(edgeCard: Bool, names: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
            if edgeCard {
                ZoneSetCard(
                    name: String(localized: .zoneSetEdgeSnappingCard),
                    zones: [],
                    subtitle: String(localized: .zoneSetEdgeSnappingSubtitle),
                    isSelected: assignedName == "edge",
                    isPreviewing: false,
                    onSelect: { model.actions?.assignZoneSet("", toScreen: selectedScreen) },
                    onPreview: nil,
                    onEdit: nil,
                    onDelete: nil,
                    onRename: nil
                )
            }
            ForEach(names, id: \.self) { name in
                let isCustom = model.customZoneSetNames.contains(name)
                ZoneSetCard(
                    name: name,
                    zones: model.zoneSets[name] ?? [],
                    subtitle: nil,
                    isSelected: assignedName == name,
                    isPreviewing: model.previewedZoneSet == name,
                    onSelect: { model.actions?.assignZoneSet(name, toScreen: selectedScreen) },
                    onPreview: { model.actions?.togglePreview(zoneSet: name, onScreen: selectedScreen) },
                    onEdit: { model.editZoneSet(named: name, onScreen: selectedScreen) },
                    onDelete: isCustom ? { model.actions?.deleteZoneSet(name) } : nil,
                    onRename: isCustom ? { _ = model.actions?.renameZoneSet(name, to: $0) } : nil
                )
            }
        }
    }

    private func createNewLayout() {
        model.actions?.editZoneSet(model.freeZoneSetName(base: String(localized: .zoneSetCustom)),
                                   seed: [ZoneRect(0, 0, 1, 1)], onScreen: selectedScreen)
    }
}

private struct ZoneSetCard: View {
    let name: String
    let zones: [ZoneRect]
    let subtitle: String?
    let isSelected: Bool
    let isPreviewing: Bool
    let onSelect: () -> Void
    let onPreview: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onRename: ((String) -> Void)?

    @State private var renaming = false
    @State private var draftName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if renaming {
                    TextField(String(localized: .zoneSetNameField), text: $draftName)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                        .onSubmit(commitRename)
                } else {
                    Text(name)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                }
                Spacer()
                if let onPreview {
                    Button(action: onPreview) {
                        Image(systemName: isPreviewing ? "eye.fill" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(isPreviewing ? Color.accentColor : Color.secondary)
                    .help(String(localized: .zoneSetShowOnScreen))
                }
                if let onEdit {
                    Button(action: onEdit) { Image(systemName: "pencil") }
                        .buttonStyle(.borderless)
                }
                if let onDelete {
                    Button(action: onDelete) { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                }
            }
            Group {
                if zones.isEmpty {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.12))
                        .overlay(
                            Text(subtitle ?? String(localized: .zoneSetEmptyCard))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(6)
                        )
                } else {
                    ZoneCanvas(zones: zones)
                }
            }
            .aspectRatio(16.0 / 10.0, contentMode: .fit)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.06)))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Color.accentColor : Color.gray.opacity(0.25),
                              lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .contextMenu {
            if onRename != nil {
                Button(String(localized: .zoneSetRename)) {
                    draftName = name
                    renaming = true
                }
            }
        }
    }

    private func commitRename() {
        let trimmed = draftName.trimmingCharacters(in: .whitespaces)
        renaming = false
        guard !trimmed.isEmpty, trimmed != name else { return }
        onRename?(trimmed)
    }
}
