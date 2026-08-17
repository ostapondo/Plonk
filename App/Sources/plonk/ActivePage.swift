import SwiftUI

// Stay active: keep the idle clock at zero, by hand, on a schedule, or while a
// particular app is open.

struct ActivePage: View {
    @ObservedObject var model: AppModel

    private var timeout: Binding<Int> {
        model.binding(\.activeTimeoutMinutes)
    }

    var body: some View {
        PageShell(title: .pageActive, subtitle: .activeSubtitle) {
            if !model.activeTrusted {
                SettingsCard {
                    SettingRow(title: .activeNeedsAccessibility) {
                        Button(String(localized: .activeOpenSettings)) {
                            model.actions?.openAccessibilitySettings()
                        }
                    }
                }
            }
            SettingsCard {
                ToggleRow(title: .activeStayActive,
                          detail: statusDetail,
                          isOn: model.binding(\.activeRequested, set: { $0.setActive($1) }))
                SettingRow(title: .activeTurnOffAfter) {
                    Picker("", selection: timeout) {
                        Text(.activeNever).tag(0)
                        Text(.activeAfter30Minutes).tag(30)
                        Text(.activeAfter1Hour).tag(60)
                        Text(.activeAfter4Hours).tag(240)
                        Text(.activeAfter8Hours).tag(480)
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
            SettingsCard(title: .activeSchedule) {
                ToggleRow(title: .activeOnASchedule,
                          detail: .activeOnAScheduleHelp,
                          isOn: field(\.enabled))
                if model.config.activeSchedule.enabled {
                    SettingRow(title: .activeFrom, detail: emptyWindowHelp) {
                        DatePicker("", selection: time(\.start), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .fixedSize()
                    }
                    SettingRow(title: .activeTo) {
                        DatePicker("", selection: time(\.end), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .fixedSize()
                    }
                    SettingRow(title: .activeDays, stacked: true) { days }
                }
            }
            SettingsCard(title: .activeApps) {
                SettingRow(title: .activeAppsHelp, stacked: true) {
                    ActiveApps(model: model)
                }
            }
            SettingsCard(title: .activePower) {
                ToggleRow(title: .activeAllowOnBattery,
                          detail: .activeAllowOnBatteryHelp,
                          isOn: model.binding(\.activeAllowOnBattery))
            }
        }
    }

    /// The toggle says what was asked for; this says what is actually
    /// happening, which is not the same thing on battery, without
    /// Accessibility, or when the schedule is what turned it on.
    private var statusDetail: LocalizedStringResource? {
        model.activeOn || model.activeRequested || !model.activeTrusted
            ? model.activeStatus : nil
    }

    /// Two equal times describe no window at all rather than a whole day, so
    /// say so on the row instead of silently doing nothing.
    private var emptyWindowHelp: LocalizedStringResource? {
        model.config.activeSchedule.start == model.config.activeSchedule.end ? .activeSameTimeHelp : nil
    }

    // MARK: - Days

    private var days: some View {
        HStack(spacing: 5) {
            ForEach(Self.weekdays, id: \.self) { day in
                let selected = model.config.activeSchedule.days.contains(day)
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
        var next = model.config.activeSchedule
        if next.days.contains(day) { next.days.remove(day) } else { next.days.insert(day) }
        model.actions?.update(\.activeSchedule, to: next)
    }

    // MARK: - Bindings

    private func field<Value>(_ keyPath: WritableKeyPath<ActiveSchedule, Value>) -> Binding<Value> {
        Binding(
            get: { model.config.activeSchedule[keyPath: keyPath] },
            set: { value in
                var next = model.config.activeSchedule
                next[keyPath: keyPath] = value
                model.actions?.update(\.activeSchedule, to: next)
            }
        )
    }

    /// The schedule stores minutes from midnight, because it repeats and a date
    /// does not. DatePicker wants a Date, so one is built on today and only its
    /// time of day is read back.
    private func time(_ keyPath: WritableKeyPath<ActiveSchedule, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = model.config.activeSchedule[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: minutes / 60,
                                             minute: minutes % 60,
                                             second: 0,
                                             of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                var next = model.config.activeSchedule
                next[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                model.actions?.update(\.activeSchedule, to: next)
            }
        )
    }
}
