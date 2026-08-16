import AppKit

// Answering `rectangle://` as well as this app's own scheme, if asked to.
//
// Declaring both schemes in the bundle makes this an eligible handler for
// each, which is not the same as being the chosen one. Apple does not document
// how LaunchServices picks between two claimants, and in practice it follows
// install order, so the choice is made here through NSWorkspace instead.
//
// Off unless asked for. Since declaring a scheme is enough to win it by
// accident, off also means handing it back to an installed Rectangle.

enum RectangleURLs {
    static let scheme = "rectangle"
    static let bundleID = "com.knollsoft.Rectangle"

    /// Where an installed Rectangle is, or nil when there is none to defer to.
    static var installed: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    /// Whether this app is what macOS currently opens a `rectangle://` URL with.
    static var isHandler: Bool {
        guard let probe = URL(string: "\(scheme)://\(URLCommand.host)?name=left-half"),
              let handler = NSWorkspace.shared.urlForApplication(toOpen: probe)
        else { return false }
        return handler.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL
    }

    enum Move: Equatable {
        case take
        case giveBack
        case nothing
    }

    /// The rule `setHandled` follows, without the LaunchServices database it
    /// would otherwise take to check.
    ///
    /// Giving the scheme back needs a claimant: with no Rectangle installed it
    /// stays here whatever `wanted` says, because there is nowhere to put it.
    static func move(wanted: Bool, isHandler: Bool, rectangleInstalled: Bool) -> Move {
        if wanted { return isHandler ? .nothing : .take }
        return isHandler && rectangleInstalled ? .giveBack : .nothing
    }

    /// Take the scheme, or give it back. A no-op when the answer already
    /// matches, so it is safe to call repeatedly.
    ///
    /// `settled` carries who holds the scheme once macOS has answered, which is
    /// not the same tick: reading `isHandler` straight after this returns still
    /// gives the old holder.
    static func setHandled(_ wanted: Bool, settled: @escaping (Bool) -> Void = { _ in }) {
        switch move(wanted: wanted, isHandler: isHandler, rectangleInstalled: installed != nil) {
        case .take:
            hand(to: Bundle.main.bundleURL, settled: settled)
        case .giveBack:
            guard let rectangle = installed else { return settled(isHandler) }
            hand(to: rectangle, settled: settled)
        case .nothing:
            settled(isHandler)
        }
    }

    /// macOS prompts before a default handler changes for http, https and
    /// html. A private scheme is not on that list, so this runs unprompted, and
    /// the only way to know it took is to ask again once it has finished.
    private static func hand(to app: URL, settled: @escaping (Bool) -> Void) {
        NSWorkspace.shared.setDefaultApplication(at: app, toOpenURLsWithScheme: scheme) { error in
            if let error {
                NSLog("Plonk: could not hand \(scheme):// to \(app.lastPathComponent): \(error)")
            }
            DispatchQueue.main.async { settled(isHandler) }
        }
    }
}
