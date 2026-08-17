import AppKit
import SwiftUI

// The two things that answer "can an agent actually reach this?" — who is
// connected, and where the API is. Both were only visible on other pages, which
// is the wrong place for the question a new user asks first.

struct HomeStatus: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            agents
            api
        }
    }

    // MARK: - Agents

    private var agents: some View {
        VStack(spacing: 0) {
            header(.homeConnectedAgents)
            if model.connectedAgents.isEmpty {
                row {
                    Text(.homeNoAgentYet)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(String(localized: .homeSetOneUp)) { model.selectedPage = "ai" }
                        .buttonStyle(.link)
                        .font(.system(size: 12))
                }
            }
            ForEach(model.connectedAgents, id: \.self) { name in
                row {
                    Circle()
                        .fill(driving(name) ? Color.green : Color.secondary)
                        .frame(width: 7, height: 7)
                    Text(name).font(.system(size: 12.5))
                    Spacer()
                    Text(driving(name) ? LocalizedStringResource.homeDriving : .homeIdle)
                        .font(.system(size: 11.5))
                        .muted()
                }
            }
            row {
                Text(.homeOnlySelectedDrives)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: model.binding(\.agentExclusive))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
        }
        .card()
    }

    /// With no agent selected every agent may drive, so every one of them is
    /// driving; that is what an empty selection means, not "none of them".
    private func driving(_ name: String) -> Bool {
        guard model.config.agentExclusive, let selected = model.config.selectedAgent else { return true }
        return selected == name
    }

    // MARK: - Local API

    private var api: some View {
        VStack(spacing: 0) {
            header(.aiLocalApi)
            row {
                Text("127.0.0.1:\(ControlServer.port)")
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                Spacer()
                if let warning = model.apiWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .help(warning)
                } else {
                    Text(.homeListening).font(.system(size: 11.5)).muted()
                }
            }
            // Shown, never copied: a token on the pasteboard is a token every
            // other app on the Mac can read, and the MCP server reads the file
            // for itself.
            row {
                Text(.homeToken).font(.system(size: 12.5))
                Spacer()
                Text(.homeTokenStored)
                    .font(.system(size: 11.5))
                    .muted()
                Button(String(localized: .homeReveal)) { revealToken() }
                    .buttonStyle(.link)
                    .font(.system(size: 12))
            }
            row {
                Text(.homeLoopbackOnly)
                    .font(.caption)
                    .muted()
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .card()
    }

    private func revealToken() {
        NSWorkspace.shared.activateFileViewerSelecting([APIToken.url()])
    }

    // MARK: - Pieces

    private func header(_ title: LocalizedStringResource) -> some View {
        HStack {
            Text(String(localized: title).uppercased())
                .font(.system(size: 10, weight: .bold))
                .kerning(0.8)
                .muted()
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 11)
        .padding(.bottom, 8)
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 9) { content() }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
        }
    }
}
