import AppKit
import Carbon.HIToolbox
import SwiftUI

// Shortcut rows, rendered inside whichever module owns them. Each row shows
// where the window lands rather than naming it, because a shape is quicker to
// recognise than "Bottom Left" is to read.

struct ShortcutRows: View {
    @ObservedObject var model: AppModel
    let actions: [HotkeyAction]
    @State private var recording: HotkeyAction?

    var body: some View {
        ForEach(actions) { action in
            LabeledContent {
                HStack(spacing: 5) {
                    if model.unavailableHotkeys.contains(action.rawValue) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .help("Another app already owns this combination")
                    }
                    ShortcutField(
                        display: model.hotkeyDisplays[action.rawValue] ?? "None",
                        isRecording: recording == action,
                        onStart: { recording = action },
                        onFinish: { hotkey in
                            recording = nil
                            if let hotkey { model.actions?.setHotkey(action, to: hotkey) }
                        },
                        onClear: {
                            recording = nil
                            model.actions?.clearHotkey(action)
                        }
                    )
                }
            } label: {
                HStack(spacing: 10) {
                    thumbnail(action)
                    Text(action.title)
                }
            }
            .disabled(!model.hotkeysEnabled)
        }
    }

    /// A screen with the target area filled in, same language as the drag overlay.
    private func thumbnail(_ action: HotkeyAction) -> some View {
        let size = CGSize(width: 34, height: 21)
        return ZStack {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.gray.opacity(0.5), lineWidth: 1)
            if let frac = action.preset?.frac {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor.opacity(0.75))
                    .frame(width: max(frac.w * size.width - 3, 3),
                           height: max(frac.h * size.height - 3, 3))
                    .position(x: (frac.x + frac.w / 2) * size.width,
                              y: (frac.y + frac.h / 2) * size.height)
            } else {
                Image(systemName: action.symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// A focusable field that swallows one key press and reports it back.
private struct ShortcutField: NSViewRepresentable {
    let display: String
    let isRecording: Bool
    let onStart: () -> Void
    let onFinish: (Hotkey?) -> Void
    let onClear: () -> Void

    func makeNSView(context: Context) -> RecorderView { RecorderView() }

    func updateNSView(_ view: RecorderView, context: Context) {
        view.onStart = onStart
        view.onFinish = onFinish
        view.onClear = onClear
        view.apply(display: display, recording: isRecording)
    }
}

final class RecorderView: NSView {
    var onStart: (() -> Void)?
    var onFinish: ((Hotkey?) -> Void)?
    var onClear: (() -> Void)?

    private let label = NSTextField(labelWithString: "")
    private var recording = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 5
        label.alignment = .center
        label.font = .systemFont(ofSize: 12, weight: .medium)
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 84),
            heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 84, height: 22) }

    func apply(display: String, recording: Bool) {
        self.recording = recording
        label.stringValue = recording ? "Press keys" : display
        label.textColor = recording ? .controlAccentColor : .labelColor
        layer?.backgroundColor = (recording ? NSColor.controlAccentColor.withAlphaComponent(0.18)
                                            : NSColor.quaternaryLabelColor).cgColor
        layer?.borderWidth = recording ? 1 : 0
        layer?.borderColor = NSColor.controlAccentColor.cgColor
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onStart?()
    }

    override func resignFirstResponder() -> Bool {
        if recording { onFinish?(nil) }
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        switch Int(event.keyCode) {
        case kVK_Escape:
            onFinish?(nil)
        case kVK_Delete, kVK_ForwardDelete:
            onClear?()
        default:
            // A bare key would fire while typing anywhere, so it is refused
            // rather than saved and left mysteriously dead.
            guard let hotkey = Hotkey(event: event) else { NSSound.beep(); return }
            onFinish?(hotkey)
        }
        window?.makeFirstResponder(nil)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }
}
