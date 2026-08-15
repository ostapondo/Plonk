import AppKit
import SwiftUI

// The first three minutes.
//
// An installed window manager that has never moved a window is indistinguishable
// from one that does not work, and the part people never find on their own is
// that an agent can drive this one. So the Home page opens with three steps —
// grant, snap, connect — and stops showing them once they are done.
//
// Each step latches: it stays ticked once it has happened, because an agent
// that quits is not a step the user has to do again. The card disappears on
// its own when all three are ticked, and can be dismissed before that.

/// Which of the three first steps are done, and what to say about the next one.
/// Pure, so the copy and the logic can be tested without a window.
struct GettingStarted: Equatable {
    struct Step: Identifiable, Equatable {
        let id: String
        let title: LocalizedStringResource
        let detail: LocalizedStringResource
        let done: Bool
    }

    var accessibilityGranted: Bool
    var snapped: Bool
    var agentConnected: Bool

    var steps: [Step] {
        [
            Step(id: "grant", title: .startGrant,
                 detail: .startGrantDetail,
                 done: accessibilityGranted),
            Step(id: "snap", title: .startSnap,
                 detail: .startSnapDetail,
                 done: snapped),
            Step(id: "agent", title: .startAgent,
                 detail: .startAgentDetail,
                 done: agentConnected),
        ]
    }

    var doneCount: Int { steps.filter(\.done).count }
    var isComplete: Bool { doneCount == steps.count }

    /// The first step still to do, which is the one worth pointing at.
    var next: Step? { steps.first { !$0.done } }

    /// Dismissing hides it early; finishing hides it for good. Both are checked
    /// here rather than at the call site, so the two reasons stay in one place.
    static func isVisible(hidden: Bool, complete: Bool) -> Bool { !hidden && !complete }
}

struct GettingStartedCard: View {
    @ObservedObject var model: AppModel
    @State private var copied = false

    private static let connectCommand = "claude mcp add plonk -- npx -y plonk-mcp"

    private var guide: GettingStarted {
        GettingStarted(accessibilityGranted: model.accessibilityGranted,
                       snapped: model.sawFirstSnap,
                       agentConnected: model.sawFirstAgent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            VStack(spacing: 0) {
                ForEach(Array(guide.steps.enumerated()), id: \.element.id) { index, step in
                    if index > 0 { Divider() }
                    row(step)
                }
            }
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.primary.opacity(0.08)))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor.opacity(0.28)))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(.startTitle).font(.subheadline.bold())
            Text(.startProgress(guide.doneCount, guide.steps.count))
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.07)))
            Spacer()
            Button(.startHide) { model.actions?.hideGettingStarted() }
                .buttonStyle(.link)
                .font(.caption)
                .help(String(localized: .startHideHelp))
        }
    }

    @ViewBuilder
    private func row(_ step: GettingStarted.Step) -> some View {
        HStack(spacing: 10) {
            Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15))
                .foregroundStyle(step.done ? Color.green : Color.secondary.opacity(0.5))
            VStack(alignment: .leading, spacing: 1) {
                Text(step.title)
                    .font(.callout.weight(.medium))
                    .strikethrough(step.done, color: .secondary)
                    .foregroundStyle(step.done ? .secondary : .primary)
                if !step.done {
                    Text(step.detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if !step.done { action(for: step) }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private func action(for step: GettingStarted.Step) -> some View {
        switch step.id {
        case "grant":
            Button(.startGrantButton) {
                open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            }
        case "snap":
            Button(.startShowZones) { model.actions?.flashZones() }
        default:
            HStack(spacing: 6) {
                Button(copied ? LocalizedStringResource.startCopied : .startCopyCommand) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(Self.connectCommand, forType: .string)
                    copied = true
                }
                .help(Self.connectCommand)
                Button(.startHow) { model.selectedPage = "ai" }
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
    }

    private func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}
