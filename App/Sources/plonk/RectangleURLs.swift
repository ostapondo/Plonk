import AppKit

// Answering `rectangle://` as well as this app's own scheme, if asked to.
//
// Both schemes are declared in the bundle, which makes this an eligible handler
// for each. Eligible is not the same as chosen: which app LaunchServices hands
// a scheme to when two of them claim it is not something Apple documents, and
// in practice it follows whichever bundle was registered last. So the choice is
// made here, out loud, rather than left to an accident of install order.
//
// Off unless the user says otherwise, and off means off. Declaring the scheme
// is enough to win it by accident, so this hands it back to an installed
// Rectangle when it finds itself holding something nobody asked for. A setting
// that only described what should have happened would not be worth having.

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

    /// Take the scheme, or give it back. Nothing happens when the answer is
    /// already right, so this is safe to call on every launch and every toggle.
    ///
    /// Giving it back needs somewhere to give it to. With no Rectangle
    /// installed there is no other claimant, so the scheme stays here and
    /// `wanted` was only ever about whether to ask for it.
    static func setHandled(_ wanted: Bool) {
        if wanted {
            guard !isHandler else { return }
            hand(to: Bundle.main.bundleURL)
        } else {
            guard isHandler, let rectangle = installed else { return }
            hand(to: rectangle)
        }
    }

    /// macOS asks the user before a default handler changes for http, https and
    /// html. A private scheme like this one is not on that list, so this is the
    /// whole of it: no prompt, and no way to be sure it took except by asking
    /// again, which `isHandler` does.
    private static func hand(to app: URL) {
        NSWorkspace.shared.setDefaultApplication(at: app, toOpenURLsWithScheme: scheme) { error in
            if let error {
                NSLog("Plonk: could not hand \(scheme):// to \(app.lastPathComponent): \(error)")
            }
        }
    }
}
