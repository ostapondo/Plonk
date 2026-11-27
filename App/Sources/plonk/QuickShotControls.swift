import AppKit

struct QuickShotControls {
    let dimensions = QuickShotDimensions()
    let toolbar: QuickShotToolbar
    private let stylePanel = QuickShotStylePanel()
    private let safeArea: CGRect

    init(fixed: Bool, safeArea: CGRect, perform: @escaping (QuickShotToolbar.Action) -> Void) {
        toolbar = QuickShotToolbar(fixed: fixed, perform: perform)
        self.safeArea = safeArea
        dimensions.isHidden = fixed
    }

    var views: [NSView] { [dimensions, toolbar, stylePanel] }

    func contains(_ point: CGPoint) -> Bool {
        (!toolbar.isHidden && toolbar.frame.contains(point)) ||
            (!dimensions.isHidden && dimensions.frame.contains(point)) || handlesStyleClick(at: point)
    }

    func handlesStyleClick(at point: CGPoint) -> Bool { stylePanel.contains(point) }

    func showRegion(hasSelection: Bool, isCreating: Bool) {
        toolbar.isHidden = !hasSelection || isCreating
        dimensions.isHidden = !hasSelection
        if toolbar.isHidden { stylePanel.dismiss() }
    }

    func place(over selection: CGRect, annotation: ShotAnnotationState, toolbarSize: CGSize? = nil) {
        let size = toolbarSize ?? toolbar.fittedSize(availableWidth: safeArea.width - 10)
        let position = QuickShotLayout.place(dimensions: dimensions.frame.size, toolbar: size,
                                            selection: selection, area: safeArea)
        dimensions.frame = position.dimensions
        toolbar.frame = position.toolbar
        placeStylePanel(annotation, avoiding: selection)
    }

    func placeFixed(imageSize: CGSize, annotation: ShotAnnotationState) -> CGRect {
        let size = toolbar.fittedSize(availableWidth: safeArea.width - 20)
        let position = QuickShotLayout.fixed(image: imageSize, toolbar: size,
                                             reserve: QuickShotStyleControls.size.height, area: safeArea)
        toolbar.frame = position.toolbar
        placeStylePanel(annotation, avoiding: position.image)
        return position.image
    }

    private func placeStylePanel(_ annotation: ShotAnnotationState, avoiding image: CGRect) {
        guard !toolbar.isHidden, let tool = annotation.tool, let anchor = toolbar.anchor(for: tool) else {
            return stylePanel.dismiss()
        }
        var obstacles = [image]
        if !dimensions.isHidden { obstacles.append(dimensions.frame) }
        stylePanel.show(tool, annotation: annotation, anchor: anchor, toolbar: toolbar.frame,
                        avoiding: obstacles, area: safeArea)
    }
}
