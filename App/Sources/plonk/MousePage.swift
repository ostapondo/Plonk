import SwiftUI

// Pointer and clicks: the tools that only ever read the mouse, and how each of
// them is drawn. A colour left unset follows the zone colour, so the page can
// be ignored entirely and the desk stays one colour; see PointerAppearance.

struct MousePage: View {
    @ObservedObject var model: AppModel

    private var look: PointerAppearance { PointerAppearance(model.config) }

    var body: some View {
        PageShell(title: .pageMouse, subtitle: .mousePointerHelp) {
            clicks
            crosshairs
            finding
            SettingsCard(title: .commonShortcuts, note: .mouseShortcutsHelp) {
                SettingBlock {
                    ShortcutRows(model: model, actions: HotkeyAction.owned(by: "mouse"))
                }
            }
        }
    }

    // MARK: - The ring

    private var clicks: some View {
        SettingsCard(title: .mouseClicks) {
            ToggleRow(title: .mouseRingClicks,
                      detail: .mouseRingClicksHelp,
                      isOn: model.binding(\.highlightClicksEnabled))
            // Off means gone rather than greyed, as on the Zones page: six
            // settings for a ring that is not drawn are six settings in the
            // way of the switch that draws it.
            if model.config.highlightClicksEnabled {
                ColorRow(title: .mouseColour,
                         fallback: look.tint,
                         following: .mouseColourFollowsZones,
                         custom: .mouseColourCustom,
                         clearTitle: .mouseUseTheZoneColour,
                         hex: model.config.clickColorHex) {
                    model.actions?.update(\.clickColorHex, to: $0)
                }
                ColorRow(title: .mouseRightColour,
                         fallback: look.click,
                         following: .mouseRightColourFollows,
                         custom: .mouseColourCustom,
                         clearTitle: .mouseMatchLeftClicks,
                         hex: model.config.rightClickColorHex) {
                    model.actions?.update(\.rightClickColorHex, to: $0)
                }
                SegmentedRow(title: .mouseShape,
                             selection: model.binding(\.clickStyle),
                             options: PointerAppearance.ClickStyle.allCases.map {
                                 (label: $0.title, tag: $0.rawValue)
                             })
                MeasureRow(title: .mouseSize, help: .mouseSizeHelp,
                           range: Config.clickRadiusRange, value: model.config.clickRadius) {
                    model.actions?.update(\.clickRadius, to: $0)
                }
                MeasureRow(title: .mouseThickness, help: .mouseThicknessHelp,
                           range: Config.clickLineWidthRange, value: model.config.clickLineWidth) {
                    model.actions?.update(\.clickLineWidth, to: $0)
                }
                MeasureRow(title: .mouseFade, help: .mouseFadeHelp,
                           range: Config.clickFadeRange, unit: .milliseconds,
                           value: model.config.clickFadeSeconds) {
                    model.actions?.update(\.clickFadeSeconds, to: $0)
                }
            }
        }
    }

    // MARK: - The lines

    private var crosshairs: some View {
        SettingsCard(title: .mouseCrosshairsCard) {
            ToggleRow(title: .mouseCrosshairs,
                      detail: .mouseCrosshairsHelp,
                      isOn: model.binding(\.crosshairsEnabled))
            if model.config.crosshairsEnabled {
                ColorRow(title: .mouseColour,
                         fallback: look.tint,
                         following: .mouseColourFollowsZones,
                         custom: .mouseColourCustom,
                         clearTitle: .mouseUseTheZoneColour,
                         hex: model.config.crosshairColorHex) {
                    model.actions?.update(\.crosshairColorHex, to: $0)
                }
                MeasureRow(title: .mouseThickness, help: .mouseThicknessHelp,
                           range: Config.crosshairLineWidthRange,
                           value: model.config.crosshairLineWidth) {
                    model.actions?.update(\.crosshairLineWidth, to: $0)
                }
                MeasureRow(title: .mouseOpacity, range: Config.opacityRange, unit: .percent,
                           value: model.config.crosshairOpacity) {
                    model.actions?.update(\.crosshairOpacity, to: $0)
                }
            }
        }
    }

    // MARK: - The circle

    /// No switch of its own: finding the pointer is a shortcut, so this card
    /// is what the flash looks like when the shortcut is pressed.
    private var finding: some View {
        SettingsCard(title: .mouseFinding, note: .mouseFindingHelp) {
            MeasureRow(title: .mouseCircle, help: .mouseCircleHelp,
                       range: Config.spotlightRadiusRange, value: model.config.spotlightRadius) {
                model.actions?.update(\.spotlightRadius, to: $0)
            }
            MeasureRow(title: .mouseDimming, help: .mouseDimmingHelp,
                       range: Config.dimRange, unit: .percent, value: model.config.spotlightDim) {
                model.actions?.update(\.spotlightDim, to: $0)
            }
        }
    }
}
