import SwiftUI

// The lower half of the Zones page: how the overlay looks, the other way to
// move a window, and the apps none of it applies to.

struct ZonesTuning: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            appearance
            grabMove
            exclusions
        }
    }

    // MARK: - Appearance

    // The three measurements first and together, then the colour, then the two
    // switches. A card that alternates between a number and a switch reads as
    // a list of unrelated things rather than one question about how the overlay
    // is drawn.
    private var appearance: some View {
        SettingsCard(title: .zonesOverlay,
                     note: .zonesOverlayHelp) {
            MeasureRow(title: .zonesGap, help: .zonesGapHelp,
                       range: 0...Config.gapLimit, value: model.config.zoneGap) {
                model.actions?.update(\.zoneGap, to: $0)
            }
            MeasureRow(title: .zonesEdgeSpanning, help: .zonesEdgeSpanningHelp,
                       range: 0...Config.edgeSpanLimit,
                       value: model.config.zoneEdgeSpanPoints) {
                model.actions?.update(\.zoneEdgeSpanPoints, to: $0)
            }
            MeasureRow(title: .zonesOpacity, range: Config.opacityRange, unit: .percent,
                       value: model.config.zoneOpacity) {
                model.actions?.update(\.zoneOpacity, to: $0)
            }
            ColorRow(title: .zonesColour,
                     fallback: model.config.appearance.accent,
                     following: .zonesColourFollowsAccent,
                     custom: .zonesColourCustom,
                     clearTitle: .zonesUseTheAccent,
                     hex: model.config.zoneColorHex) {
                model.actions?.update(\.zoneColorHex, to: $0)
            }
            ToggleRow(title: .zonesNumberTheZones,
                      isOn: model.binding(\.zoneNumbersVisible))
            ToggleRow(title: .zonesEveryMonitor,
                      isOn: model.binding(\.zonesOnAllMonitors))
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
