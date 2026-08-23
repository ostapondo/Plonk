import SwiftUI

// Pulse: hold the Mac up, say whether that also means holding your chat status
// at available, and say what starts a session without being asked.
//
// The cards are in the order the questions come: what it does, when it starts
// by itself, and what power gets to override it.

struct AwakePage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        PageShell(title: .pageAwake, subtitle: .awakeSubtitle) {
            // Only when the level that needs the grant is on: Accessibility
            // buys the assertion nothing, so asking for it before then would be
            // a demand for a permission the page does not use.
            if model.config.awakeAvailable && !model.awakeTrusted {
                SettingsCard {
                    SettingRow(title: .awakeNeedsAccessibility) {
                        Button(String(localized: .awakeOpenSettings)) {
                            PrivacySettings.openAccessibility()
                        }
                    }
                }
            }
            SettingsCard {
                ToggleRow(title: .awakeKeepNow,
                          detail: statusDetail,
                          isOn: model.binding(\.awakeHeld, set: { $0.setAwake($1) }))
                ToggleRow(title: .awakeAvailable,
                          detail: .awakeAvailableHelp,
                          isOn: model.binding(\.awakeAvailable))
                SettingRow(title: .awakeTurnOffAfter) {
                    Picker("", selection: model.binding(\.awakeTimeoutMinutes)) {
                        Text(.awakeNever).tag(0)
                        Text(.awakeAfter15Minutes).tag(15)
                        Text(.awakeAfter30Minutes).tag(30)
                        Text(.awakeAfter1Hour).tag(60)
                        Text(.awakeAfter2Hours).tag(120)
                        Text(.awakeAfter4Hours).tag(240)
                        Text(.awakeAfter8Hours).tag(480)
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
            SettingsCard(title: .awakeSchedule) {
                ToggleRow(title: .awakeOnASchedule,
                          detail: .awakeOnAScheduleHelp,
                          isOn: model.binding(\.awakeSchedule.enabled))
                if model.config.awakeSchedule.enabled {
                    SettingRow(title: .awakeFrom, detail: emptyWindowHelp) {
                        DatePicker("", selection: time(\.awakeSchedule.start),
                                   displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .fixedSize()
                    }
                    SettingRow(title: .awakeTo) {
                        DatePicker("", selection: time(\.awakeSchedule.end),
                                   displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .fixedSize()
                    }
                    SettingRow(title: .awakeDays, stacked: true) { days }
                }
            }
            SettingsCard(title: .awakeApps) {
                SettingRow(title: .awakeAppsHelp, stacked: true) {
                    AwakeApps(model: model)
                }
            }
            SettingsCard(title: .awakePower) {
                ToggleRow(title: .awakeKeepDisplayOn,
                          detail: .awakeKeepDisplayOnHelp,
                          isOn: model.binding(\.awakeKeepDisplayOn))
                ToggleRow(title: .awakeAllowOnBattery,
                          detail: .awakeAllowOnBatteryHelp,
                          isOn: model.binding(\.awakeAllowOnBattery))
                ToggleRow(title: .awakeAutoWhileCharging,
                          detail: .awakeAutoWhileChargingHelp,
                          isOn: model.binding(\.awakeAutoWhileCharging))
                if model.hasLid {
                    ToggleRow(title: .awakeLidClosed,
                              detail: .awakeLidClosedHelp,
                              isOn: model.binding(\.awakeLidClosed))
                }
            }
        }
    }

    /// The toggle says what was asked for; this says what is actually
    /// happening, which is not the same thing on battery, without
    /// Accessibility, or when the schedule is what turned it on.
    private var statusDetail: LocalizedStringResource? {
        model.awakeOn || model.awakeHeld ? model.awakeStatus : nil
    }

    /// Two equal times describe no window at all rather than a whole day, so
    /// say so on the row instead of silently doing nothing.
    private var emptyWindowHelp: LocalizedStringResource? {
        model.config.awakeSchedule.start == model.config.awakeSchedule.end ? .awakeSameTimeHelp : nil
    }

    // MARK: - Days

    private var days: some View {
        HStack(spacing: 5) {
            ForEach(Self.weekdays, id: \.self) { day in
                let selected = model.config.awakeSchedule.days.contains(day)
                Button(Self.symbol(for: day)) { toggle(day) }
                    .buttonStyle(.borderless)
                    .frame(width: 32, height: 22)
                    .background(selected ? Color.accentColor : Color.secondary.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 5))
                    .foregroundStyle(selected ? Color.white : Color.primary)
            }
        }
    }

    /// Calendar weekday numbers in the order this locale writes the week, which
    /// starts on Monday in most of the world and on Sunday in some of it.
    private static var weekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    private static func symbol(for weekday: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        guard symbols.indices.contains(weekday - 1) else { return "" }
        return symbols[weekday - 1]
    }

    private func toggle(_ day: Int) {
        var days = model.config.awakeSchedule.days
        if days.contains(day) { days.remove(day) } else { days.insert(day) }
        model.actions?.update(\.awakeSchedule.days, to: days)
    }

    /// The schedule stores minutes from midnight, because it repeats and a date
    /// does not. DatePicker wants a Date, so one is built on today and only its
    /// time of day is read back.
    private func time(_ keyPath: WritableKeyPath<Config, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = model.config[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: minutes / 60,
                                             minute: minutes % 60,
                                             second: 0,
                                             of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                model.actions?.update(keyPath, to: (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
            }
        )
    }
}
