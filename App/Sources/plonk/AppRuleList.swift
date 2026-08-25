import AppKit
import SwiftUI

// The rules, as a list of apps with a zone each: the app is picked the way an
// exclusion is, then the row says which zone its windows open into and, when
// it matters, on which screen.

struct AppRuleList: View {
    @ObservedObject var model: AppModel

    /// The screens a rule can name, by the UUID it is stored under. A screen
    /// with no UUID cannot be named, so it is left out rather than offered as
    /// a choice that would save nothing.
    private var screens: [(index: Int, uuid: String)] {
        (0..<model.screenCount).compactMap { index in
            ScreenIdentity.uuid(forIndex: index).map { (index, $0) }
        }
    }

    var body: some View {
        // Once per redraw, not once per row: each is a display UUID per
        // screen, and the page redraws on every change to the model.
        let attached = screens
        if model.config.appRules.isEmpty {
            Text(.rulesNone)
                .foregroundStyle(.secondary)
        }
        ForEach(model.config.appRules, id: \.app) { rule in
            row(rule, attached: attached)
        }
        AppAdder(prompt: .excludedAdd) { add($0) }
    }

    private func row(_ rule: AppRule, attached: [(index: Int, uuid: String)]) -> some View {
        let known = AppPicker.installedApp(for: rule.app)
        let named = attached.first { $0.uuid == rule.screenUUID }?.index
        return AppRow(title: known?.name ?? rule.app, icon: known?.icon, removeHelp: .rulesRemove) {
            model.actions?.update(\.appRules, to: AppRules.remove(app: rule.app, from: model.config.appRules))
        } subtitle: {
            if known != nil {
                Text(rule.app).monospaced()
            } else {
                Text(.excludedMatchedAnywhere)
            }
        } accessory: {
            zonePicker(rule, named: named)
            screenPicker(rule, attached: attached, named: named)
        }
    }

    /// Every edit goes back by the rule's own identity, its app, so a row
    /// edited while an agent removes another one still edits the right rule.
    private func write(_ rule: AppRule) {
        model.actions?.update(\.appRules, to: AppRules.upsert(rule, in: model.config.appRules))
    }

    /// The zones the rule's screen has, or the most any screen has when the
    /// rule follows the window; and whatever the rule already says, when an
    /// agent has pointed it past that.
    private func zonePicker(_ rule: AppRule, named: Int?) -> some View {
        let count = named.map { model.zones(onScreen: $0).count } ?? mostZones
        var choices = Array(1...max(count, 1))
        if !choices.contains(rule.zone) { choices.append(rule.zone) }
        return Picker("", selection: Binding(
            get: { rule.zone },
            set: { zone in
                var changed = rule
                changed.zone = zone
                write(changed)
            }
        )) {
            ForEach(choices, id: \.self) { zone in
                Text(.shortcutZone(zone)).tag(zone)
            }
        }
        .labelsHidden()
        .fixedSize()
    }

    /// The most zones any attached screen has: what a rule that follows the
    /// window can name.
    private var mostZones: Int {
        (0..<model.screenCount).map { model.zones(onScreen: $0).count }.max() ?? 0
    }

    /// The screen the zone is on. A display the rule names but which is not
    /// attached stays on the list under its own entry, so opening the row
    /// does not silently rewrite it to whatever is plugged in today. Naming
    /// a screen holds the zone to what that screen has, the way the route
    /// does, so the row cannot say a zone that will never fire.
    private func screenPicker(_ rule: AppRule, attached: [(index: Int, uuid: String)], named: Int?) -> some View {
        let away = named == nil ? rule.screenUUID : nil
        return Picker("", selection: Binding(
            get: { rule.screenUUID },
            set: { uuid in
                var changed = rule
                changed.screenUUID = uuid
                let count = uuid.flatMap { chosen in attached.first { $0.uuid == chosen }?.index }
                    .map { model.zones(onScreen: $0).count } ?? mostZones
                if count > 0 { changed.zone = min(changed.zone, count) }
                write(changed)
            }
        )) {
            Text(.rulesThisScreen).tag(String?.none)
            ForEach(attached, id: \.uuid) { screen in
                Text(.zoneSetScreen(screen.index + 1)).tag(String?.some(screen.uuid))
            }
            if let away {
                Text(.rulesScreenAway).tag(String?.some(away))
            }
        }
        .labelsHidden()
        .fixedSize()
    }

    /// A new app goes into zone 1 on the screen it opens on; the row is where
    /// that gets changed. An app already on the list is left as it is.
    private func add(_ pattern: String) {
        guard !model.config.appRules.contains(where: { AppRules.same($0.app, pattern) }) else { return }
        write(AppRule(app: pattern, zone: 1))
    }
}
