import CoreGraphics

/// What a mouse-down on the Quick Actions canvas does.
enum QuickShotPress: Equatable {
    case mark
    case adjust(handle: CGPoint)
    case select
    case ignore

    /// `handle` is `ShotSelection.handle(at:of:)`, `.zero` when off every edge.
    /// A press outside the selection would start a new one and drop the marks,
    /// so it does nothing while any display still holds marks or redo history.
    init(handle: CGPoint, insideSelection: Bool, drawing: Bool, marksExist: Bool) {
        if handle != .zero {
            self = .adjust(handle: handle)
        } else if insideSelection {
            self = drawing ? .mark : .adjust(handle: .zero)
        } else {
            self = marksExist ? .ignore : .select
        }
    }
}
