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
    @Environment(\.colorScheme) private var scheme

    /// A shortcut is 300 points of content, so rows flow into as many columns
    /// as the card is wide: one on a narrow window, two or three on a desk.
    /// A single column of them in a full-width card was a page of left-hand
    /// names staring at right-hand keys across a gulf of nothing.
    /// Shared with the Keyboard page, whose read-only rows are the same shape.
    static let columns = [GridItem(.adaptive(minimum: 300, maximum: 430),
                                   spacing: 14, alignment: .leading)]

    var body: some View {
        LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 7) {
            ForEach(actions) { action in
                row(action)
            }
        }
    }

    private func row(_ action: HotkeyAction) -> some View {
        // Deliberately not a LabeledContent, for the reason spelled out on
        // MeasureRow: a form row splits itself into a label and a control,
        // and it put the recorder on a line of its own whatever width the
        // field was given. That cost every row a second line and stretched
        // an 84pt field across the width of the window. A plain row with a
        // Spacer in it is the whole fix.
        HStack(spacing: 10) {
            thumbnail(action)
            // A zone set shortcut carries the name of the set that is at
            // that place in the list today, because that is what pressing
            // it applies. "Zone set 3" is only the fallback for a place the
            // list does not reach.
            if let set = zoneSet(action) {
                Text(set.name).lineLimit(1).truncationMode(.tail)
            } else {
                Text(action.title).lineLimit(1).truncationMode(.tail)
            }
            Spacer(minLength: 12)
            if model.unavailableHotkeys.contains(action.rawValue) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help(String(localized: .shortcutAlreadyTaken))
            }
            ShortcutField(
                display: model.hotkeyDisplays[action.rawValue] ?? String(localized: .shortcutUnbound),
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
        // On a surface of its own, because the grid's cells have no other
        // edge: a key right-aligned in an invisible cell sat nearer the next
        // shortcut's name than its own.
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Ink.raised(scheme)))
        .disabled(!model.config.hotkeysEnabled)
    }

    /// A screen with the target area filled in, same language as the drag
    /// overlay.
    ///
    /// A numbered zone draws the set that is actually on the main screen, the
    /// target filled and the rest outlined round it, because "Zone 5" names
    /// nothing on its own — the picture is the only thing on the row that says
    /// where the window lands. A number the set has no zone for draws an empty
    /// screen, which is exactly what pressing it does.
    private func thumbnail(_ action: HotkeyAction) -> some View {
        let size = CGSize(width: 34, height: 21)
        return ZStack {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.gray.opacity(0.5), lineWidth: 1)
            if let frac = action.preset?.frac {
                area(frac.x, frac.y, frac.w, frac.h, in: size, inset: 3, fill: 0.75)
            } else if let number = action.zoneNumber {
                // Tighter inset than a preset gets: a six-zone set drawn with
                // the three-point one loses its narrow zones altogether.
                ForEach(Array(model.zones(onScreen: 0).enumerated()), id: \.offset) { index, zone in
                    area(zone.x, zone.y, zone.w, zone.h, in: size, inset: 1.5,
                         fill: index + 1 == number ? 0.75 : 0)
                }
            } else if let set = zoneSet(action) {
                // The whole arrangement rather than one zone of it, so it is
                // filled throughout and more faintly than a target is.
                ForEach(Array(set.zones.enumerated()), id: \.offset) { _, zone in
                    area(zone.x, zone.y, zone.w, zone.h, in: size, inset: 1.5, fill: 0.45)
                }
            } else {
                Image(systemName: action.symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// The set a zone-set shortcut applies today, by its place in the list.
    /// Nil for every other action, and for a place the list does not reach.
    private func zoneSet(_ action: HotkeyAction) -> (name: String, zones: [ZoneRect])? {
        guard let number = action.layoutNumber else { return nil }
        let names = model.zoneSetNames
        guard names.indices.contains(number - 1) else { return nil }
        let name = names[number - 1]
        return (name, model.zoneSets[name] ?? [])
    }

    /// One rectangle of that picture. Filled where the window lands, outlined
    /// where it is only one of the zones around it.
    private func area(_ x: Double, _ y: Double, _ w: Double, _ h: Double,
                      in size: CGSize, inset: CGFloat, fill: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: 1.5)
        return Group {
            if fill > 0 {
                shape.fill(Color.accentColor.opacity(fill))
            } else {
                shape.strokeBorder(Color.gray.opacity(0.4), lineWidth: 0.75)
            }
        }
        .frame(width: max(w * size.width - inset, 2),
               height: max(h * size.height - inset, 2))
        .position(x: (x + w / 2) * size.width, y: (y + h / 2) * size.height)
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

    /// Answers with the field's own size whatever the row proposes, so the row
    /// cannot stretch it. Without this a representable takes the width it is
    /// offered, which is the whole window.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: RecorderView, context: Context) -> CGSize? {
        nsView.fittingWidth
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

    /// Wide enough for what it is showing, and never narrower than 84 so a
    /// column of them lines up. "⌃⌥⇧⌘Space" is a legal binding and would be
    /// clipped by a fixed width.
    ///
    /// Measured once in `apply`, not on demand: SwiftUI asks for the size
    /// several times per layout pass for every field on the page, and each
    /// measurement of the label lays its text out again.
    private(set) var fittingWidth = NSSize(width: 84, height: 22)
    private var measuredText: String?

    override var intrinsicContentSize: NSSize { fittingWidth }

    func apply(display: String, recording: Bool) {
        self.recording = recording
        let text = recording ? String(localized: .shortcutPressKeys) : display
        if text != measuredText {
            measuredText = text
            label.stringValue = text
            fittingWidth = NSSize(width: max(84, ceil(label.intrinsicContentSize.width) + 18), height: 22)
            invalidateIntrinsicContentSize()
        }
        label.textColor = recording ? .controlAccentColor : .labelColor
        layer?.backgroundColor = (recording ? NSColor.controlAccentColor.withAlphaComponent(0.18)
                                            : NSColor.quaternaryLabelColor).cgColor
        // Bordered whether it is recording or not: a flat pill in a column of
        // eleven reads as a label, and nothing said it could be clicked.
        layer?.borderWidth = 1
        layer?.borderColor = (recording ? NSColor.controlAccentColor
                                        : NSColor.separatorColor).cgColor
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
        let key = Int(event.keyCode)
        let held = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if key == kVK_Escape {
            onFinish?(nil)
        } else if key == kVK_Delete || key == kVK_ForwardDelete, held.isEmpty {
            // Bare delete clears the row. Held with a modifier it is a key like
            // any other: Rectangle's own restore is ⌃⌥⌫, and an imported
            // binding the recorder will not take back is worse than none.
            onClear?()
        } else if let hotkey = Hotkey(event: event) {
            onFinish?(hotkey)
        } else {
            // A bare key would fire while typing anywhere, so it is refused
            // rather than saved and left mysteriously dead.
            NSSound.beep()
            return
        }
        window?.makeFirstResponder(nil)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }
}
