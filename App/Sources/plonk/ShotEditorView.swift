import SwiftUI

// Screenshot annotation editor: pick a shape, colour and width, draw over the
// capture, then copy or save the flattened result.

struct ShotEditorView: View {
    let image: NSImage
    let defaultFolder: String
    let onFinish: (_ copied: Bool, _ savedPath: String?) -> Void

    @State private var annotations: [Annotation] = []
    @State private var redoStack: [Annotation] = []
    @State private var live: Annotation?
    @State private var kind: Annotation.Kind = .arrow
    @State private var colorIndex = 0
    @State private var strokePoints: Double = 4
    @State private var status: String?

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
                    Image(systemName: kind.symbol).tag(kind).help(kind.title)
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
                if let last = annotations.popLast() { redoStack.append(last) }
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(annotations.isEmpty)
            .help(String(localized: .shotEditorUndo))

            Button {
                if let last = redoStack.popLast() { annotations.append(last) }
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(redoStack.isEmpty)
            .help(String(localized: .shotEditorRedo))
        }
        .padding(10)
    }

    private var canvas: some View {
        GeometryReader { geo in
            // The image is aspect-fitted inside the pane, so gesture points get
            // mapped against that rect and not the pane.
            let fitted = ImageFit.rect(for: image.size, in: geo.size)
            AnnotatedImage(image: image, annotations: annotations, live: live)
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            live = extend(live, to: value, in: fitted)
                        }
                        .onEnded { _ in
                            if let live { annotations.append(live); redoStack.removeAll() }
                            live = nil
                        }
                )
        }
    }

    private func extend(_ current: Annotation?, to value: DragGesture.Value, in fitted: CGRect) -> Annotation {
        let start = ImageFit.unitPoint(value.startLocation, in: fitted)
        let point = ImageFit.unitPoint(value.location, in: fitted)
        guard var annotation = current else {
            return Annotation(kind: kind, points: [start], colorIndex: colorIndex,
                              width: strokePoints / max(fitted.width, 1))
        }
        if kind.tracksEveryPoint {
            annotation.points.append(point)
        } else {
            annotation.points = [start, point]
        }
        return annotation
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

    @MainActor
    private func flattened() -> NSImage? {
        image.annotated(with: annotations)
    }

    private func copy() {
        guard let output = flattened() else {
            status = String(localized: .shotEditorRenderFailed)
            return
        }
        ScreenshotManager.copyToClipboard(output)
        onFinish(true, nil)
    }

    private func save(to destination: ScreenshotManager.Destination) {
        guard let output = flattened() else {
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
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = ScreenshotManager.fileName(for: Date())
        panel.directoryURL = URL(fileURLWithPath: (defaultFolder as NSString).expandingTildeInPath)
        if panel.runModal() == .OK, let url = panel.url {
            save(to: .path(url.path))
        }
    }
}
