import SwiftUI

// Where a first-time user lands.
//
// Leads with the thing the app is for, drawn rather than described: the zone
// set that is actually on the main screen, with the shortcut that fills it.
// Permissions used to open this page as three chips that were green every day;
// they live in the top bar now and only take room when one of them is not.

struct HomePage: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    private var guide: GettingStarted {
        GettingStarted(accessibilityGranted: model.accessibilityGranted,
                       screenRecordingGranted: model.screenRecordingGranted,
                       snapped: model.config.sawFirstSnap,
                       agentConnected: model.config.sawFirstAgent)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let warning = model.configWarning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.10)))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.orange.opacity(0.35)))
                }
                if model.rectangleFound {
                    RectangleOffer(model: model)
                }
                if GettingStarted.isVisible(hidden: model.config.gettingStartedHidden, complete: guide.isComplete) {
                    GettingStartedCard(model: model)
                }
                hero
                SectionHead(title: .homeQuickActions)
                quickActions
                SectionHead(title: .homeWhatIsOn)
                switches
                HomeStatus(model: model)
                Text(.homePrivacy)
                    .font(.caption)
                    .muted()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(20)
        }
    }

    // MARK: - Hero

    // The picture is the first thing to go when the window is narrow: the
    // sentence and the button still say what the app does, and a squeezed
    // preview says nothing at all.
    private var hero: some View {
        ViewThatFits(in: .horizontal) {
            heroBody(preview: true)
            heroBody(preview: false)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Ink.card(scheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(RadialGradient(colors: [model.accent.opacity(0.14), .clear],
                                             center: .topTrailing, startRadius: 0, endRadius: 460))
                )
        )
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Ink.gradient(model.accent), lineWidth: 1.2))
        .shadow(color: model.accent.opacity(scheme == .dark ? 0.18 : 0.10), radius: 18, y: 6)
    }

    private func heroBody(preview: Bool) -> some View {
        HStack(alignment: .center, spacing: 22) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 5, height: 5)
                    Text(.homeReady)
                        .font(.system(size: 10, weight: .bold))
                        .kerning(1)
                        .foregroundStyle(model.accent)
                }
                .opacity(ready ? 1 : 0)
                Text(.homeHeadline)
                    .font(.system(size: 26, weight: .bold))
                    .kerning(-0.4)
                    .padding(.top, 9)
                Text(.homeTagline)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 7)
                HStack(spacing: 9) {
                    Button { model.actions?.flashZones() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.grid.2x2").font(.system(size: 12))
                            Text(.homeShowZones).font(.system(size: 12.5, weight: .medium))
                            KeyCaps(parts: keys(.showZones))
                        }
                        .fixedSize()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 13)
                        .frame(height: 32)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Ink.gradient(model.accent)))
                        .shadow(color: model.accent.opacity(0.45), radius: 10, y: 3)
                    }
                    .buttonStyle(.plain)
                    Button(String(localized: .homeEditZonesButton)) { model.actions?.openZonePicker() }
                        .controlSize(.large)
                        .fixedSize()
                }
                .padding(.top, 15)
            }
            // Fixed beside the picture, free without it. Left to itself the
            // sentence asks for one long line, and ViewThatFits would never
            // find room for the wide arrangement at any window size.
            .frame(width: preview ? 320 : nil, alignment: .leading)
            .frame(maxWidth: preview ? nil : .infinity, alignment: .leading)
            if preview {
                Spacer(minLength: 0)
                ZonePreview(zones: previewZones, accent: model.accent)
                    .frame(width: 288, height: 172)
            }
        }
    }

    /// The set assigned to the main screen, so the picture is of this Mac and
    /// not of a layout nobody chose. Empty means edge snapping, which has no
    /// zones to draw.
    private var previewZones: [ZoneRect] { model.zones(onScreen: 0) }

    /// The same three facts the top bar's pill reports, so the badge cannot
    /// claim everything is ready while the bar says a permission is missing.
    private var ready: Bool {
        model.accessibilityGranted && model.screenRecordingGranted && model.apiWarning == nil
    }

    private func keys(_ action: HotkeyAction) -> [String] {
        model.hotkeyParts[action.rawValue] ?? []
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        HStack(spacing: 10) {
            tile(.homeCaptureRegion, "camera.viewfinder", keys: keys(.captureRegion)) {
                model.actions?.capture(.region)
            }
            tile(.homeShowZones, "square.grid.2x2", keys: keys(.showZones)) {
                model.actions?.flashZones()
            }
            tile(.homeEditZones, "pencil.and.outline", keys: []) {
                model.actions?.openZonePicker()
            }
            tile(model.awakeHeld ? LocalizedStringResource.homeAwakeOn : .homeKeepAwake,
                 "cup.and.saucer", keys: []) {
                model.actions?.setAwake(!model.awakeHeld)
            }
        }
    }

    private func tile(_ title: LocalizedStringResource, _ icon: String, keys: [String],
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: icon).font(.system(size: 16)).foregroundStyle(model.accent)
                    Spacer(minLength: 6)
                    KeyCaps(parts: keys)
                }
                Text(title).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .card()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Switches

    // Only what can be turned on and off. Everything that needs a choice rather
    // than a switch lives on its own page, so this list has one job.
    private var switches: some View {
        VStack(spacing: 0) {
            switchRow(.homeHotkeys, "keyboard",
                      detail: model.unavailableHotkeys.isEmpty
                          ? .homeHotkeysDetail
                          : .homeHotkeysTaken(model.unavailableHotkeys.joined(separator: ", ")),
                      toggle: model.binding(\.hotkeysEnabled))
            Divider()
            switchRow(.homeDragToSnap, "rectangle.3.group",
                      detail: .homeDragToSnapDetail,
                      toggle: model.binding(\.dragSnapEnabled))
            Divider()
            switchRow(.homeKeepAwake, "cup.and.saucer",
                      detail: model.awakeHeld && !model.awakeOn
                          ? LocalizedStringResource.homeKeepAwakePaused : .homeKeepAwakeDetail,
                      toggle: model.binding(\.awakeHeld, set: { $0.setAwake($1) }))
            Divider()
            switchRow(.homeLaunchAtLogin, "power",
                      detail: .homeLaunchAtLoginDetail,
                      toggle: model.binding(\.loginItemRegistered,
                                            set: { $0.update(\.launchAtLogin, to: $1) }))
        }
        .card()
    }

    private func switchRow(_ title: LocalizedStringResource, _ icon: String,
                           detail: LocalizedStringResource,
                           toggle: Binding<Bool>) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon).frame(width: 20).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12.5, weight: .medium))
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: toggle).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
        .padding(11)
    }
}

/// The main screen with its zones on it, at the size of a postcard. Drawn from
/// the same fractions the overlay uses, so it is a picture of the real layout.
struct ZonePreview: View {
    let zones: [ZoneRect]
    let accent: Color
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(Color.secondary.opacity(0.4)).frame(width: 4, height: 4)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 15)
            .background(Ink.raised(scheme))
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(Array(zones.enumerated()), id: \.offset) { index, zone in
                        tile(index: index, zone: zone, in: geo.size)
                    }
                    if zones.isEmpty {
                        Text(.homeEdgeSnapping)
                            .font(.caption)
                            .muted()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .padding(6)
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Ink.raised(scheme).opacity(0.5)))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Ink.stroke(scheme)))
    }

    /// Zone two is drawn as the drop target, so the picture shows what the
    /// overlay looks like mid-drag rather than a set of empty boxes.
    private func tile(index: Int, zone: ZoneRect, in size: CGSize) -> some View {
        let lit = index == 1
        let width = max(size.width * zone.w - 5, 1)
        let height = max(size.height * zone.h - 5, 1)
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return shape
            .fill(lit ? accent.opacity(0.26) : Ink.card(scheme))
            .overlay(shape.strokeBorder(lit ? accent : Ink.stroke(scheme), lineWidth: lit ? 1.5 : 1))
            .overlay(number(index + 1, lit: lit))
            .frame(width: width, height: height)
            .offset(x: size.width * zone.x + 2.5, y: size.height * zone.y + 2.5)
    }

    private func number(_ value: Int, lit: Bool) -> some View {
        Text("\(value)")
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(lit ? accent : Color.secondary)
    }
}
