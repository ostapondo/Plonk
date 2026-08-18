import AppKit
import SwiftUI

/// The system blur, behind the window. SwiftUI's materials sit inside the
/// window; only NSVisualEffectView gives a floating panel the desktop showing
/// through it, or the sidebar the vibrancy the system one has.
struct VisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    /// `.active` keeps a panel blurred whether or not it is key; the sidebar
    /// follows the window like every other one.
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.state = state
    }
}
