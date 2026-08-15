import SwiftUI

// Zones, ordered by what has to be true before the next thing means anything:
// which set is on which screen, then the two ways a window gets into one
// (dragging, shortcuts), then what happens when the desktop changes underneath.
// Looks and the neighbouring features are further down, in ZonesTuning.

struct ZonesPage: View {
    @ObservedObject var model: AppModel

    /// Everything on this page that is not one of the three grouped sections.
    private var presetActions: [HotkeyAction] {
        let grouped: Set<String> = ["Numbered zones", "Zone sets", "Focus"]
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
        SettingsCard(title: "Dragging",
                     note: "Holding the modifier while dragging inverts the mode, so the other "
                         + "behaviour is always available. Hold ⌘ as well and the zone you started "
                         + "over and the one under the cursor are dropped into as one.") {
            ToggleRow(title: "Drag to snap",
                      detail: "Drop windows into zones or screen edges",
                      isOn: model.binding(\.dragSnapEnabled, set: { $0.setDragSnap($1) }))
            SegmentedRow(title: "Show zones",
                         selection: model.binding(\.zonesRequireModifier,
                                                  set: { $0.setZonesRequireModifier($1) }),
                         options: [("While dragging", false), ("With the modifier", true)],
                         stacked: true)
            SegmentedRow(title: "Modifier",
                         selection: model.binding(\.zonesModifier, set: { $0.setZonesModifier($1) }),
                         options: [("⇧ Shift", "shift"), ("⌥ Option", "option"), ("⌃ Control", "control")])
        }
    }

    // MARK: - Shortcuts

    private var shortcuts: some View {
        SettingsCard(title: "Halves, quarters and the rest") {
            SettingBlock {
                ShortcutRows(model: model, actions: presetActions)
            }
        }
    }

    private var numbered: some View {
        SettingsCard(title: "Numbered zones",
                     note: "The numbers the overlay draws, on whichever screen the front window is "
                         + "on. ⌃⌥0 gives a window back the frame it had before Plonk first moved "
                         + "it. Click a key field and press the combination; Esc cancels, Delete "
                         + "unbinds.") {
            SettingBlock {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "zones",
                                                                       group: "Numbered zones"))
            }
        }
    }

    private var switching: some View {
        SettingsCard(title: "Switch zone sets",
                     note: "Applies the set at that place in the list of zone sets, to whichever "
                         + "screen the cursor is on. Windows already sitting in a numbered zone "
                         + "move to where that number is in the new set. The last shortcut puts "
                         + "the same list on screen to pick from, or to open one in the editor.") {
            SettingBlock {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "zones", group: "Zone sets"))
            }
        }
    }

    private var focus: some View {
        SettingsCard(title: "Move between windows",
                     note: "Focus follows the layout instead of the order things were last used: "
                         + "step to the window that is actually to the left, or cycle through the "
                         + "ones stacked in a zone.") {
            SettingBlock {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "zones", group: "Focus"))
            }
        }
    }

    // MARK: - Desktop changes

    private var desktopChanges: some View {
        SettingsCard(title: "When the desktop changes") {
            ToggleRow(title: "Put windows back after a display change",
                      detail: "Windows Plonk placed return to the same spot on the same monitor "
                          + "when one is plugged in or unplugged",
                      isOn: model.binding(\.restoreZonesOnScreenChange,
                                          set: { $0.setRestoreZonesOnScreenChange($1) }))
            ToggleRow(title: "Send new windows where that app's last one went",
                      detail: "Once an app's window has been put in a zone, its next one lands "
                          + "there too. Forgotten when Plonk quits",
                      isOn: model.binding(\.placeNewWindows, set: { $0.setPlaceNewWindows($1) }))
        }
    }
}
