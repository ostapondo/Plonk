import SwiftUI

// How the zones behave: the way the overlay is drawn, when Plonk runs it
// again by itself, and the apps none of it applies to.

struct ZonesTuning: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            appearance
            keys
            desktopChanges
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

    // MARK: - Keys

    private var keys: some View {
        SettingsCard(title: .zonesKeys) {
            ToggleRow(title: .zonesCycleHalves,
                      detail: .zonesCycleHalvesDetail,
                      isOn: model.binding(\.presetsCycleOnRepeat))
        }
    }

    // MARK: - Desktop changes

    private var desktopChanges: some View {
        SettingsCard(title: .zonesDesktopChanges) {
            ToggleRow(title: .zonesRestoreOnDisplayChange,
                      detail: .zonesRestoreOnDisplayChangeDetail,
                      isOn: model.binding(\.restoreZonesOnScreenChange))
            // Widens the switch above; with that one off there is nothing
            // to widen, so this one is put away rather than left dead.
            if model.config.restoreZonesOnScreenChange {
                ToggleRow(title: .zonesRestoreEveryWindow,
                          detail: .zonesRestoreEveryWindowDetail,
                          isOn: model.binding(\.restoreEveryWindowOnScreenChange))
            }
            ToggleRow(title: .zonesPlaceNewWindows,
                      detail: .zonesPlaceNewWindowsDetail,
                      isOn: model.binding(\.placeNewWindows))
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
