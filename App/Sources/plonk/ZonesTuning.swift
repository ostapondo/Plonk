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
        SettingsCard(title: .zonesOverlay,
                     note: .zonesOverlayHelp) {
            SettingBlock {
                PointsField(title: .zonesGap, help: .zonesGapHelp,
                            placeholder: "0", range: 0...Config.gapLimit, value: model.zoneGap) {
                    model.actions?.setZoneGap($0)
                }
            }
            SettingRow(title: .zonesOpacity, stacked: true) {
                Slider(value: $opacityDraft, in: 0.1...1) { editing in
                    if !editing { model.actions?.setZoneOpacity(opacityDraft) }
                }
            }
            SettingRow(title: .zonesColour,
                       detail: model.zoneColorHex == nil
                           ? LocalizedStringResource.zonesColourFollowsAccent : nil) {
                HStack(spacing: 10) {
                    ColorPicker("", selection: zoneColor, supportsOpacity: false).labelsHidden()
                    Button(String(localized: .zonesUseTheAccent)) { model.actions?.setZoneColor(nil) }
                        .controlSize(.small)
                        .disabled(model.zoneColorHex == nil)
                }
            }
            ToggleRow(title: .zonesNumberTheZones,
                      isOn: model.binding(\.zoneNumbersVisible, set: { $0.setZoneNumbersVisible($1) }))
            ToggleRow(title: .zonesEveryMonitor,
                      isOn: model.binding(\.zonesOnAllMonitors, set: { $0.setZonesOnAllMonitors($1) }))
            SettingBlock {
                PointsField(title: .zonesEdgeSpanning,
                            help: .zonesEdgeSpanningHelp,
                            placeholder: "16", range: 0...60, value: model.zoneEdgeSpan) {
                    model.actions?.setZoneEdgeSpan($0)
                }
            }
        }
    }

    // MARK: - Grab and move

    private var grabMove: some View {
        SettingsCard(title: .zonesGrabMove,
                     note: .zonesGrabMoveHelp) {
            ToggleRow(title: .zonesGrabAnywhere,
                      detail: .zonesGrabAnywhereDetail,
                      isOn: model.binding(\.grabMoveEnabled, set: { $0.setGrabMove($1) }))
            Group {
                SegmentedRow(title: .zonesHold,
                             selection: model.binding(\.grabMoveModifier,
                                                      set: { $0.setGrabMoveModifier($1) }),
                             options: [(.zonesModifierOption, "option"),
                                       (.zonesModifierCommand, "command"),
                                       (.zonesModifierControl, "control")])
                ToggleRow(title: .zonesRightDragResizes,
                          detail: .zonesRightDragResizesDetail,
                          isOn: model.binding(\.grabMoveResize, set: { $0.setGrabMoveResize($1) }))
                ToggleRow(title: .zonesShowSizeWhileDragging,
                          isOn: model.binding(\.grabMoveShowGeometry,
                                              set: { $0.setGrabMoveShowGeometry($1) }))
            }
            .disabled(!model.grabMoveEnabled)
            .opacity(model.grabMoveEnabled ? 1 : 0.5)
        }
    }

    // MARK: - Exclusions

    private var exclusions: some View {
        SettingsCard(title: .zonesExclusions,
                     note: .zonesExclusionsHelp) {
            SettingBlock {
                ExcludedApps(model: model)
            }
        }
    }
}
