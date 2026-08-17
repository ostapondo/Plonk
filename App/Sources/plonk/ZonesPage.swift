import SwiftUI

// Zones, ordered by what has to be true before the next thing means anything:
// which set is on which screen, then the two ways a window gets into one
// (dragging, shortcuts), then what happens when the desktop changes underneath.
// Looks and the neighbouring features are further down, in ZonesTuning.

struct ZonesPage: View {
    @ObservedObject var model: AppModel

    /// Everything on this page that is not one of the three grouped sections.
    private var presetActions: [HotkeyAction] {
        let grouped: Set<HotkeyAction.Group> = [.numberedZones, .zoneSets, .focus]
        return HotkeyAction.owned(by: "zones").filter { !grouped.contains($0.group) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZoneSetCanvas(model: model)
                HStack(alignment: .top, spacing: 12) {
                    dragging
                    shortcuts
                }
                numbered
                switching
                focus
                desktopChanges
                ZonesTuning(model: model)
            }
            .padding(20)
        }
    }

    // MARK: - Dragging

    private var dragging: some View {
        SettingsCard(title: .zonesDragging,
                     note: .zonesDraggingHelp) {
            ToggleRow(title: .zonesDragToSnap,
                      detail: .zonesDragToSnapDetail,
                      isOn: model.binding(\.dragSnapEnabled))
            SegmentedRow(title: .zonesShowZones,
                         selection: model.binding(\.zonesRequireShift),
                         options: [(.zonesWhileDragging, false), (.zonesWithTheModifier, true)],
                         stacked: true)
            SegmentedRow(title: .zonesModifier,
                         selection: model.binding(\.zonesModifier),
                         options: [(.zonesModifierShift, "shift"),
                                   (.zonesModifierOption, "option"),
                                   (.zonesModifierControl, "control")])
        }
    }

    // MARK: - Shortcuts

    private var shortcuts: some View {
        SettingsCard(title: .zonesPresets) {
            SettingBlock {
                ShortcutRows(model: model, actions: presetActions)
            }
        }
    }

    private var numbered: some View {
        SettingsCard(title: .zonesNumbered,
                     note: .zonesNumberedHelp) {
            SettingBlock {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "zones",
                                                                       group: .numberedZones))
            }
        }
    }

    private var switching: some View {
        SettingsCard(title: .zonesSwitching,
                     note: .zonesSwitchingHelp) {
            SettingBlock {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "zones", group: .zoneSets))
            }
        }
    }

    private var focus: some View {
        SettingsCard(title: .zonesFocus,
                     note: .zonesFocusHelp) {
            SettingBlock {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "zones", group: .focus))
            }
        }
    }

    // MARK: - Desktop changes

    private var desktopChanges: some View {
        SettingsCard(title: .zonesDesktopChanges) {
            ToggleRow(title: .zonesRestoreOnDisplayChange,
                      detail: .zonesRestoreOnDisplayChangeDetail,
                      isOn: model.binding(\.restoreZonesOnScreenChange))
            ToggleRow(title: .zonesPlaceNewWindows,
                      detail: .zonesPlaceNewWindowsDetail,
                      isOn: model.binding(\.placeNewWindows))
        }
    }
}
