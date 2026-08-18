import Foundation

// Where the text the user reads comes from.
//
// Every user-facing string lives in `Resources/en.lproj/Localizable.strings` and
// reaches the code as a `LocalizedStringResource` declared in one of the
// `Strings+*.swift` files. Views and menus hold keys, never sentences, so a
// translation is a new `.lproj` beside the English one and nothing else: no
// Swift file has to be touched to add a language.
//
// The catalog ships in two shapes and this picks between them. `swift build`
// leaves it in the SwiftPM resource bundle next to the binary, which is what a
// test run and `swift run` see. `scripts/build.sh` copies the `.lproj` folders
// into `Plonk.app/Contents/Resources`, where macOS expects an app's
// localizations and where the language chosen in System Settings is honored.

enum Localization {
    /// The bundle `Localizable.strings` was found in.
    static let bundle: Bundle = {
        if Bundle.main.path(forResource: "en", ofType: "lproj") != nil { return .main }
        return resourceBundle ?? .main
    }()

    /// How a `LocalizedStringResource` names that bundle. `.main` for the
    /// built app; the URL form only for the SwiftPM bundle, where nothing
    /// else finds it.
    static let description: LocalizedStringResource.BundleDescription = {
        bundle === Bundle.main ? .main : .atURL(bundle.bundleURL)
    }()

    /// SwiftPM's own resource bundle, which is what a `swift run` or a test run
    /// sees. Found by hand rather than through `Bundle.module`: that traps when
    /// the bundle is missing, and a build that lost its `.lproj` folders should
    /// draw keys on screen, not take the app down.
    ///
    /// Under `swift run` it sits beside the binary. Under `swift test` the main
    /// bundle is swiftpm's own helper, off in the toolchain, so the directory
    /// holding the test bundle is the one to look in.
    private static let resourceBundle: Bundle? = {
        // `Bundle(for:)` names whatever binary this code was loaded from, which
        // is the test bundle under `swift test` and the executable otherwise.
        let host = Bundle(for: BundleToken.self).bundleURL.deletingLastPathComponent()
        for root in [Bundle.main.bundleURL, host] {
            let candidate = root.appendingPathComponent("plonk_plonk.bundle")
            if let bundle = Bundle(url: candidate) { return bundle }
        }
        return nil
    }()
}

/// Stands in for "the binary this code is in", which is all `Bundle(for:)` is
/// being asked for.
private final class BundleToken {}

extension LocalizedStringResource {
    /// One entry of the catalog, by key.
    ///
    /// The key is symbolic (`zones.title`), not English text: the English is a
    /// translation like any other and lives in `en.lproj`. Keys that carry a
    /// value put the format specifiers in the key itself, as Foundation's
    /// interpolation does, so a key declared with one interpolated value is
    /// looked up as `zones.count %lld` and the catalog spells it that way.
    static func key(_ key: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, bundle: Localization.description)
    }
}

extension String {
    /// The text for a key, the way every call site spells it.
    ///
    /// Foundation's own `String(localized: LocalizedStringResource)` resolves
    /// through a path that reopens and reparses `Localizable.strings` on
    /// every call, close to a millisecond each; a page evaluating its body
    /// makes dozens of them and switching pages took half a second. Going
    /// through the bundle's string table instead is cached and formats the
    /// same way. This overload lives in the module, so it shadows Foundation's
    /// for every caller here; `Text(_ resource:)` was never affected.
    init(localized resource: LocalizedStringResource) {
        self.init(localized: resource.defaultValue, bundle: Localization.bundle)
    }
}
