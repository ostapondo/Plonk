import SwiftUI

// The lower half of the Zones page: how the overlay looks, the other way to
// move a window, and the apps none of it applies to.

struct ZonesTuning: View {
    @ObservedObject var model: AppModel
    @State private var opacityDraft = 1.0

    /// The picker works in colours; config stores a hex string, so a
    /// hand-edited file stays readable.
    private var zoneColor: Binding<Color> {
        Binding(
            get: { Color(nsColor: ZoneAppearance.color(fromHex: model.zoneColorHex)
                         ?? model.appearance.accent) },
            set: { model.actions?.setZoneColor(ZoneAppearance.hex(from: NSColor($0))) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            appearance
            grabMove
            exclusions
        }
        .onAppear { opacityDraft = model.zoneOpacity }
        .onChange(of: model.zoneOpacity) { opacityDraft = $0 }
    }

    // MARK: - Appearance

    private var appearance: some View {
        SettingsCard(title: "Overlay",
                     note: "The gap is real, not decoration: a window dropped into a zone keeps "
                         + "that much space around it. Edge spanning covers both zones when the "
                         + "cursor comes that close to the line between them, without holding "
                         + "anything; zero switches it off.") {
            SettingBlock {
                PointsField(title: "Gap", help: "Empty space kept around every snapped window",
                            placeholder: "0", range: 0...40, value: model.zoneGap) {
                    model.actions?.setZoneGap($0)
                }
            }
            SettingRow(title: "Opacity", stacked: true) {
                Slider(value: $opacityDraft, in: 0.1...1) { editing in
                    if !editing { model.actions?.setZoneOpacity(opacityDraft) }
                }
            }
            SettingRow(title: "Colour",
                       detail: model.zoneColorHex == nil
                           ? "Following the app's accent colour" : nil) {
                HStack(spacing: 10) {
                    ColorPicker("", selection: zoneColor, supportsOpacity: false).labelsHidden()
                    Button("Use the accent") { model.actions?.setZoneColor(nil) }
                        .controlSize(.small)
                        .disabled(model.zoneColorHex == nil)
                }
            }
            ToggleRow(title: "Number the zones",
                      isOn: model.binding(\.zoneNumbersVisible, set: { $0.setZoneNumbersVisible($1) }))
            ToggleRow(title: "Show every monitor's zones while dragging",
                      isOn: model.binding(\.zonesOnAllMonitors, set: { $0.setZonesOnAllMonitors($1) }))
            SettingBlock {
                PointsField(title: "Edge spanning",
                            help: "How near the line between two zones covers both. 0 turns it off",
                            placeholder: "16", range: 0...60, value: model.zoneEdgeSpan) {
                    model.actions?.setZoneEdgeSpan($0)
                }
            }
        }
    }

    // MARK: - Grab and move

    private var grabMove: some View {
        SettingsCard(title: "Grab and move",
                     note: "Off by default, because option-drag already means something inside "
                         + "plenty of Mac apps — duplicating a layer, copying a file. Anything in "
                         + "the exception list below is never grabbed. Add the zones modifier "
                         + "while dragging and the zones appear as usual.") {
            ToggleRow(title: "Grab windows anywhere",
                      detail: "Hold the key and drag from any point inside a window, instead of "
                          + "aiming for the title bar",
                      isOn: model.binding(\.grabMoveEnabled, set: { $0.setGrabMove($1) }))
            Group {
                SegmentedRow(title: "Hold",
                             selection: model.binding(\.grabMoveModifier,
                                                      set: { $0.setGrabMoveModifier($1) }),
                             options: [("⌥ Option", "option"), ("⌘ Command", "command"),
                                       ("⌃ Control", "control")])
                ToggleRow(title: "Right-drag resizes",
                          detail: "Pulls the edge or corner nearest where the drag started",
                          isOn: model.binding(\.grabMoveResize, set: { $0.setGrabMoveResize($1) }))
                ToggleRow(title: "Show the size while dragging",
                          isOn: model.binding(\.grabMoveShowGeometry,
                                              set: { $0.setGrabMoveShowGeometry($1) }))
            }
            .disabled(!model.grabMoveEnabled)
            .opacity(model.grabMoveEnabled ? 1 : 0.5)
        }
    }

    // MARK: - Exclusions

    private var exclusions: some View {
        SettingsCard(title: "Leave these alone",
                     note: "Dragging and the shortcuts skip these — games, remote desktops, "
                         + "anything that manages its own geometry. Asking an agent to place one "
                         + "still works, because that names the window on purpose.") {
            SettingBlock {
                ExcludedApps(model: model)
            }
        }
    }
}
