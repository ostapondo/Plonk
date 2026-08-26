import SwiftUI

// Zones, ordered by what has to be true before the next thing means anything:
// which set is on which screen, the two ways a window gets into one by hand,
// then how all of it behaves — the overlay, display changes, the apps left
// alone. The four lists of shortcuts close the page under a rule of their own:
// they are the longest thing on it and the least often changed.

struct ZonesPage: View {
    @ObservedObject var model: AppModel

    /// The placements: everything that is not one of the grouped sections and
    /// not flashing the overlay, which moves no window and is filed with the
    /// zones it shows instead.
    private var presetActions: [HotkeyAction] {
        let grouped: Set<HotkeyAction.Group> = [.numberedZones, .zoneSets, .focus, .other, .displays, .size]
        return HotkeyAction.owned(by: "zones").filter { !grouped.contains($0.group) }
    }

    /// Flashing the zones first, then the zones themselves: it is the way to
    /// see which number is which before pressing one of them.
    private var numberedActions: [HotkeyAction] {
        HotkeyAction.owned(by: "zones", group: .other)
            + HotkeyAction.owned(by: "zones", group: .numberedZones)
    }

    var body: some View {
        PageShell(title: .pageZones, subtitle: .zonesPageHelp) {
            // The settings first: which zones this screen has, the two ways
            // to drop a window into one by hand, and how all of it behaves.
            // Cards are paired by length so neither column leaves a run of
            // nothing beside the other.
            ZoneSetCanvas(model: model)
            Columns { dragging } trailing: { grabMove }
            ZonesTuning(model: model)
            // The keys close the page under a rule of their own: one card,
            // taller than everything above it put together, and set once.
            SectionHead(title: .commonShortcuts, note: .zonesShortcutsHelp)
                .padding(.top, 8)
            shortcutCard
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
                                   (.zonesModifierControl, "control")],
                         stacked: true)
        }
    }

    // MARK: - Shortcuts

    // One card rather than four: the groups are sections of one subject, and
    // four separate cards read as a scatter. Each section is a heading, its
    // rows, and its explanation right under them instead of floating beneath
    // whichever card happened to be last.
    private var shortcutCard: some View {
        SettingsCard {
            CardSection(title: .zonesPresets, first: true) {
                ShortcutRows(model: model, actions: presetActions)
            }
            CardSection(title: .zonesDisplaysAndSize, note: .zonesDisplaysAndSizeHelp) {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "zones", group: .displays)
                             + HotkeyAction.owned(by: "zones", group: .size))
            }
            CardSection(title: .zonesNumbered, note: .zonesNumberedHelp) {
                ShortcutRows(model: model, actions: numberedActions)
            }
            CardSection(title: .zonesSwitching, note: .zonesSwitchingHelp) {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "zones", group: .zoneSets))
            }
            CardSection(title: .zonesFocus, note: .zonesFocusHelp) {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "zones", group: .focus))
            }
        }
    }

    // MARK: - Grab and move

    private var grabMove: some View {
        SettingsCard(title: .zonesGrabMove,
                     note: .zonesGrabMoveHelp) {
            ToggleRow(title: .zonesGrabAnywhere,
                      detail: .zonesGrabAnywhereDetail,
                      isOn: model.binding(\.grabMoveEnabled))
            // Off means gone rather than greyed. A dimmed row still costs its
            // full height, so the card scrolled as far switched off as on, and
            // three settings for something the app is not doing are three
            // settings in the way of the one that turns it on.
            if model.config.grabMoveEnabled {
                SegmentedRow(title: .zonesHold,
                             selection: model.binding(\.grabMoveModifier),
                             options: [(.zonesModifierOption, "option"),
                                       (.zonesModifierCommand, "command"),
                                       (.zonesModifierControl, "control")])
                ToggleRow(title: .zonesRightDragResizes,
                          detail: .zonesRightDragResizesDetail,
                          isOn: model.binding(\.grabMoveResize))
                ToggleRow(title: .zonesShowSizeWhileDragging,
                          isOn: model.binding(\.grabMoveShowGeometry))
            }
        }
    }
}
