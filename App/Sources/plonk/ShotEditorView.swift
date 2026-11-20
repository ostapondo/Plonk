import SwiftUI

// Screenshot annotation editor: pick a shape, colour and width, draw over the
// capture, then copy or save the flattened result.

struct ShotEditorView: View {
    let image: NSImage
    let defaultFolder: String
    let onFinish: (_ copied: Bool, _ savedPath: String?) -> Void

    @State private var history: AnnotationHistory
    @State private var kind: Annotation.Kind = .arrow
    @State private var colorIndex = 0
    @State private var strokePoints: Double = 4
    @State private var status: String?

    init(image: NSImage, history: AnnotationHistory, defaultFolder: String,
         onFinish: @escaping (Bool, String?) -> Void) {
        self.image = image
        self.defaultFolder = defaultFolder
        self.onFinish = onFinish
        _history = State(initialValue: history)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            canvas
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.06))
            Divider()
            footer
        }
        .frame(minWidth: 700, minHeight: 520)
    }

    private var toolbar: some View {
        HStack(spacing: 14) {
            Picker("", selection: $kind) {
                ForEach(Annotation.Kind.allCases) { kind in
                    Image(systemName: kind.symbol).tag(kind).help(String(localized: kind.title))
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()

            HStack(spacing: 5) {
                ForEach(Array(Annotation.palette.enumerated()), id: \.offset) { index, color in
                    Circle()
                        .fill(color)
                        .frame(width: 17, height: 17)
                        .overlay(Circle().strokeBorder(.primary.opacity(colorIndex == index ? 0.9 : 0.2),
                                                       lineWidth: colorIndex == index ? 2.5 : 1))
                        .onTapGesture { colorIndex = index }
                }
            }

            Slider(value: $strokePoints, in: 1...16) { Text(.shotEditorWidth) }
                .frame(width: 110)

            Spacer()

            Button {
                history.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!history.canUndo)
            .help(String(localized: .shotEditorUndo))

            Button {
                history.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!history.canRedo)
            .help(String(localized: .shotEditorRedo))
        }
        .padding(10)
    }

    private var canvas: some View {
        GeometryReader { geo in
            // The image is aspect-fitted inside the pane, so gesture points get
            // mapped against that rect and not the pane.
            let fitted = ImageFit.rect(for: image.size, in: geo.size)
            AnnotatedImage(image: image, annotations: history.annotations, live: history.live)
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if history.live == nil {
                                history.begin(kind, at: ImageFit.unitPoint(value.startLocation, in: fitted),
                                              color: colorIndex, width: strokePoints / max(fitted.width, 1))
                            }
                            history.drag(to: ImageFit.unitPoint(value.location, in: fitted))
                        }
                        .onEnded { value in
                            history.end(at: ImageFit.unitPoint(value.location, in: fitted))
                        }
                )
        }
    }

    private var footer: some View {
        HStack {
            if let status {
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(String(localized: .shotEditorSaveAs), action: saveAs)
            Button(String(localized: .shotEditorSaveToFolder)) { save(to: .folder(defaultFolder)) }
            Button(String(localized: .shotEditorCopy), action: copy)
                .keyboardShortcut(.defaultAction)
        }
        .padding(10)
    }

    // MARK: - Output

    private func copy() {
        guard let output = image.annotated(with: history.annotations) else {
            status = String(localized: .shotEditorRenderFailed)
            return
        }
        ScreenshotManager.copyToClipboard(output)
        onFinish(true, nil)
    }

    private func save(to destination: ScreenshotManager.Destination) {
        guard let output = image.annotated(with: history.annotations) else {
            status = String(localized: .shotEditorRenderFailed)
            return
        }
        guard let path = ScreenshotManager.save(output, to: destination) else {
            status = String(localized: .shotEditorWriteFailed)
            return
        }
        onFinish(false, path)
    }

    private func saveAs() {
        let panel = ShotSavePanel.make(in: defaultFolder)
        let completion: (NSApplication.ModalResponse) -> Void = { response in
            if response == .OK, let url = panel.url { save(to: .path(url.path)) }
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }
}
