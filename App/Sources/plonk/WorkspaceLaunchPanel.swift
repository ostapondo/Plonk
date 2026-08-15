import AppKit
import SwiftUI

// Shown while a workspace comes up: which apps are still on their way, which
// failed, and a way to stop the rest.

struct WorkspaceLaunchPanel: View {
    @ObservedObject var model: AppModel
    let onCancel: () -> Void
    let onClose: () -> Void

    private var finished: Bool { model.launchingWorkspace == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(String(localized: model.launchingWorkspace.map { .launchLaunching($0) }
                                       ?? .launchLaunched))
                    .font(.headline)
                Spacer(minLength: 20)
                Button(finished ? LocalizedStringResource.launchClose : .commonCancel,
                       action: finished ? onClose : onCancel)
                    .controlSize(.small)
            }
            VStack(spacing: 0) {
                ForEach(Array(model.launchStatuses.enumerated()), id: \.element.id) { index, status in
                    if index > 0 { Divider() }
                    row(status)
                }
            }
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.gray.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.gray.opacity(0.20)))
        }
        .padding(18)
        .frame(width: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func row(_ status: LaunchStatus) -> some View {
        HStack(spacing: 9) {
            AppIcon(path: status.bundlePath, size: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(status.app).font(.callout).lineLimit(1)
                if let detail = detail(for: status.state) {
                    Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            indicator(status.state)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private func indicator(_ state: LaunchStatus.State) -> some View {
        switch state {
        case .pending, .launching, .waiting:
            ProgressView().controlSize(.small)
        case .placed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .skipped:
            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    private func detail(for state: LaunchStatus.State) -> String? {
        switch state {
        case .pending: return String(localized: .launchPending)
        case .launching: return String(localized: .launchOpening)
        case .waiting: return String(localized: .launchWaitingForWindow)
        case .placed: return nil
        case .skipped(let why): return why
        case .failed(let why): return why
        }
    }
}

/// Icons come from the bundle on disk, so they show for apps that are not running.
struct AppIcon: View {
    let path: String?
    var size: CGFloat = 20

    var body: some View {
        Group {
            if let path, FileManager.default.fileExists(atPath: path) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}
