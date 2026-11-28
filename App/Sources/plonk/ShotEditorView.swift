import SwiftUI

// Screenshot annotation editor: pick a shape, colour and width, draw over the
// capture, then copy or save the flattened result.

struct ShotEditorView: View {
    @ObservedObject var model: AppModel
    let image: NSImage
    let defaultFolder: String
    let onFinish: (_ copied: Bool, _ savedPath: String?) -> Void

    @ObservedObject private var annotation: ShotAnnotationState
    @State private var history: AnnotationHistory
    @State private var status: String?

    init(model: AppModel, image: NSImage, history: AnnotationHistory, annotation: ShotAnnotationState?,
         defaultFolder: String, onFinish: @escaping (Bool, String?) -> Void) {
        self.model = model
        self.image = image
        self.defaultFolder = defaultFolder
        self.onFinish = onFinish
        let annotation = annotation ?? ShotAnnotationState(defaults: model.config.shotAnnotationStyles)
        annotation.enterEditor()
        self.annotation = annotation
        _history = State(initialValue: history)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .zIndex(1)
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
            HStack(spacing: 0) {
                ForEach(Annotation.Kind.allCases) { choice in
                    let active = choice == annotation.tool
                    Button {
                        if !active { annotation.tool = choice }
                    } label: {
                        Image(systemName: choice.editorSymbol)
                            .foregroundStyle(active ? Color(nsColor: model.config.appearance.accent) : .primary)
                            .frame(width: 30, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(choice.title))
                    .accessibilityAddTraits(active ? .isSelected : [])
                    .help(String(localized: choice.title))
                }
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            .fixedSize()

            if let kind = annotation.tool {
                let style = $annotation.styles[dynamicMember: AnnotationStyles.path(for: kind)]
                AnnotationPalette(selection: style.color)
                AnnotationWidthSlider(width: style.width, range: kind.widthRange)
            }

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
                .overlay {
                    ShotEditorDragInput(
                        onDrag: { start, point, shift in
                            if history.live == nil {
                                annotation.beginMark(in: &history,
                                                     at: ImageFit.unitPoint(start, in: fitted),
                                                     viewWidth: fitted.width)
                            }
                            history.drag(to: ImageFit.unitPoint(point, in: fitted),
                                         squareIn: shift ? image.size : nil)
                        },
                        onEnd: { point, shift in
                            history.end(at: ImageFit.unitPoint(point, in: fitted),
                                        squareIn: shift ? image.size : nil)
                        },
                        onShiftChange: { shift in
                            history.updateSquareConstraint(in: shift ? image.size : nil)
                        }
                    )
                }
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
