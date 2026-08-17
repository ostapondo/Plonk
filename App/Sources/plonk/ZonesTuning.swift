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
            get: { Color(nsColor: ZoneAppearance.color(fromHex: model.config.zoneColorHex)
                         ?? model.config.appearance.accent) },
            set: { model.actions?.update(\.zoneColorHex, to: ZoneAppearance.hex(from: NSColor($0))) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            appearance
            grabMove
            exclusions
        }
        .onAppear { opacityDraft = model.config.zoneOpacity }
        .onChange(of: model.config.zoneOpacity) { opacityDraft = $0 }
    }

    // MARK: - Appearance

    private var appearance: some View {
        SettingsCard(title: .zonesOverlay,
                     note: .zonesOverlayHelp) {
            SettingBlock {
                PointsField(title: .zonesGap, help: .zonesGapHelp,
                            placeholder: "0", range: 0...Int(Config.gapLimit), value: model.config.zoneGap) {
                    model.actions?.update(\.zoneGap, to: $0)
                }
            }
            SettingRow(title: .zonesOpacity, stacked: true) {
                Slider(value: $opacityDraft, in: Config.opacityRange) { editing in
                    if !editing { model.actions?.update(\.zoneOpacity, to: opacityDraft) }
                }
            }
            SettingRow(title: .zonesColour,
                       detail: model.config.zoneColorHex == nil
                           ? LocalizedStringResource.zonesColourFollowsAccent : nil) {
                HStack(spacing: 10) {
                    ColorPicker("", selection: zoneColor, supportsOpacity: false).labelsHidden()
                    Button(String(localized: .zonesUseTheAccent)) { model.actions?.update(\.zoneColorHex, to: nil) }
                        .controlSize(.small)
                        .disabled(model.config.zoneColorHex == nil)
                }
            }
            ToggleRow(title: .zonesNumberTheZones,
                      isOn: model.binding(\.zoneNumbersVisible))
            ToggleRow(title: .zonesEveryMonitor,
                      isOn: model.binding(\.zonesOnAllMonitors))
            SettingBlock {
                PointsField(title: .zonesEdgeSpanning,
                            help: .zonesEdgeSpanningHelp,
                            placeholder: "16", range: 0...Int(Config.edgeSpanLimit), value: model.config.zoneEdgeSpanPoints) {
                    model.actions?.update(\.zoneEdgeSpanPoints, to: $0)
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
                      isOn: model.binding(\.grabMoveEnabled))
            Group {
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
            .disabled(!model.config.grabMoveEnabled)
            .opacity(model.config.grabMoveEnabled ? 1 : 0.5)
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
