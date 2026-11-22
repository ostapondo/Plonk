import SwiftUI

// Liquid Glass on macOS 26, and the closest material everywhere older. Every
// glass shape in the app goes through here, so the fallback is decided once.

/// How a piece of glass behaves: plain, tinted with the accent, or reacting to
/// the pointer the way a control does.
struct GlassStyle {
    var tint: Color?
    var interactive = false

    static let plain = GlassStyle()
    static let control = GlassStyle(interactive: true)
    static func prominent(_ tint: Color) -> GlassStyle { GlassStyle(tint: tint, interactive: true) }
}

/// Whether glass is drawn: the system has to support it and the user has to
/// want it. Views read it from the environment (`\.glassOn`), which a window
/// that observes the model sets from config, so flipping the setting redraws
/// them like any other change. `userEnabled` is only the default for a panel
/// built without the model, and is set from config before any window exists.
enum GlassSupport {
    static let systemSupports: Bool = {
        #if compiler(>=6.2)
        if #available(macOS 26, *) { return true }
        #endif
        return false
    }()

    static var userEnabled = true

    static var isNative: Bool { systemSupports && userEnabled }
}

private struct GlassOnKey: EnvironmentKey {
    static var defaultValue: Bool { GlassSupport.isNative }
}

extension EnvironmentValues {
    var glassOn: Bool {
        get { self[GlassOnKey.self] }
        set { self[GlassOnKey.self] = newValue }
    }
}

struct GlassSurface<S: InsettableShape>: ViewModifier {
    var shape: S
    var style: GlassStyle = .plain
    @Environment(\.colorScheme) private var scheme
    @Environment(\.glassOn) private var glassOn

    @ViewBuilder func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if glassOn, #available(macOS 26, *) {
            content.glassEffect(glass, in: shape)
        } else {
            materialSurface(content)
        }
        #else
        materialSurface(content)
        #endif
    }

    #if compiler(>=6.2)
    @available(macOS 26, *)
    private var glass: Glass26 {
        var glass = Glass26.regular
        if let tint = style.tint { glass = glass.tint(tint) }
        return glass.interactive(style.interactive)
    }
    #endif

    private func materialSurface(_ content: Content) -> some View {
        content
            .background {
                if let tint = style.tint {
                    shape.fill(tint)
                } else {
                    shape.fill(.regularMaterial)
                }
            }
            .overlay(shape.strokeBorder(Ink.glassEdge(scheme)))
    }
}

#if compiler(>=6.2)
@available(macOS 26, *)
typealias Glass26 = SwiftUI.Glass
#endif

extension View {
    func glassSurface(radius: CGFloat, style: GlassStyle = .plain) -> some View {
        modifier(GlassSurface(shape: RoundedRectangle(cornerRadius: radius, style: .continuous),
                              style: style))
    }

    func glassCapsule(_ style: GlassStyle = .plain) -> some View {
        modifier(GlassSurface(shape: Capsule(style: .continuous), style: style))
    }
}

extension View {
    /// Sets `\.glassOn` from the user's setting. Every window that observes the
    /// model applies it at its root, so flipping the switch redraws in place.
    func glass(from model: AppModel) -> some View {
        environment(\.glassOn, GlassSupport.systemSupports && model.config.appearance.liquidGlass)
    }
}
