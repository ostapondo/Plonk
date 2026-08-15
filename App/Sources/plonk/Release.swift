import Foundation

// Everything about a published release that can be worked out without touching
// the network or the disk, so the update path is testable without either.

/// A dotted version, tolerant of the "v" GitHub puts on tags.
struct ReleaseVersion: Comparable, CustomStringConvertible {
    let parts: [Int]
    let text: String

    init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let body = trimmed.hasPrefix("v") || trimmed.hasPrefix("V")
            ? String(trimmed.dropFirst()) : trimmed
        // A pre-release suffix ("0.1.0-beta.2") orders below its own release,
        // which is more than this needs: releases that carry one are skipped
        // before they ever get here.
        let numeric = body.prefix { $0.isNumber || $0 == "." }
        let parts = numeric.split(separator: ".").compactMap { Int($0) }
        guard !parts.isEmpty else { return nil }
        self.parts = parts
        self.text = body
    }

    var description: String { text }

    static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        let width = max(lhs.parts.count, rhs.parts.count)
        for index in 0..<width {
            let left = index < lhs.parts.count ? lhs.parts[index] : 0
            let right = index < rhs.parts.count ? rhs.parts[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    static func == (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

struct Release: Equatable {
    let version: ReleaseVersion
    /// The .zip asset holding Plonk.app.
    let downloadURL: URL
    let pageURL: URL
    let notes: String
    /// Asset size in bytes, for the progress bar. Zero when GitHub omits it.
    let size: Int64
    /// The asset's SHA-256, hex, as GitHub records it — nil for releases made
    /// before it started publishing one. It arrives in the same response as
    /// the download URL, so it is no defence against a feed that lies: that is
    /// what the signature check is for. What it catches is the download itself
    /// going wrong — truncated, cached stale, swapped between the feed and the
    /// disk — and it catches it before a byte is unpacked or run.
    let digest: String?

    /// GitHub writes the digest as "sha256:<hex>". Anything else — a missing
    /// field, another algorithm, a malformed hash — reads as nil rather than
    /// failing the update: a release that predates the field is still a
    /// release, and the signature check has not moved.
    static func hexSHA256(from raw: Any?) -> String? {
        guard let text = raw as? String else { return nil }
        let parts = text.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, parts[0].lowercased() == "sha256" else { return nil }
        let hex = parts[1].lowercased()
        guard hex.count == 64, hex.allSatisfy(\.isHexDigit) else { return nil }
        return hex
    }

    /// Reads GitHub's `releases/latest` payload. Drafts and pre-releases are
    /// rejected rather than offered: they are published to be tried by hand.
    static func parse(_ data: Data) throws -> Release {
        // Whatever comes back leaves as an UpdateError: the text reaches the
        // user, and "JSON text did not start with array or object" does not
        // tell them anything they can act on.
        let parsed = try? JSONSerialization.jsonObject(with: data)
        guard let root = parsed as? [String: Any] else {
            throw UpdateError.malformedFeed("the release feed was not an object")
        }
        if root["draft"] as? Bool == true || root["prerelease"] as? Bool == true {
            throw UpdateError.malformedFeed("the latest release is a draft or pre-release")
        }
        guard let tag = root["tag_name"] as? String, let version = ReleaseVersion(tag) else {
            throw UpdateError.malformedFeed("the release has no usable tag_name")
        }
        // The app archive, not merely the first zip: a release that also
        // carries symbols or checksums would otherwise hand the updater
        // whichever asset happened to be uploaded first, and every installed
        // copy would follow it. The named form wins, a lone zip is the
        // fallback for releases made before the name settled.
        let assets = (root["assets"] as? [[String: Any]]) ?? []
        let zips = assets.filter { ($0["name"] as? String)?.hasSuffix(".zip") == true }
        let named = zips.first { ($0["name"] as? String)?.hasPrefix("Plonk-") == true }
        guard let asset = named ?? (zips.count == 1 ? zips.first : nil),
              let download = (asset["browser_download_url"] as? String).flatMap(URL.init(string:)) else {
            throw UpdateError.malformedFeed(
                zips.isEmpty
                    ? "release \(version) ships no .zip asset"
                    : "release \(version) ships several zips and none is named Plonk-<version>.zip"
            )
        }
        let page = (root["html_url"] as? String).flatMap(URL.init(string:))
            ?? URL(string: "https://github.com/\(repository)/releases/latest")!
        return Release(
            version: version,
            downloadURL: download,
            pageURL: page,
            notes: (root["body"] as? String) ?? "",
            size: (asset["size"] as? NSNumber)?.int64Value ?? 0,
            digest: hexSHA256(from: asset["digest"])
        )
    }

    static let repository = "ostapondo/plonk"
    static let latestURL = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    static let releasesPageURL = URL(string: "https://github.com/\(repository)/releases/latest")!

    /// Swaps the staged copy in once the running one has exited. It has to
    /// outlive the app it is replacing, so it is a script rather than work on a
    /// queue: nothing in this process is around to finish the job. Paths arrive
    /// as arguments, never interpolated, so a space or a quote in one cannot
    /// turn into shell syntax.
    static let installScript = """
    #!/bin/sh
    # Written by Plonk. Replaces an installed Plonk.app with a verified copy.
    set -u
    pid=$1
    staged=$2
    installed=$3

    # The app quits right after spawning this; 10s is long past generous.
    waited=0
    while kill -0 "$pid" 2>/dev/null; do
    	[ "$waited" -ge 100 ] && exit 1
    	waited=$((waited + 1))
    	sleep 0.1
    done

    aside="$installed.plonk-old"
    rm -rf "$aside"
    mv "$installed" "$aside" || exit 1
    if ! ditto "$staged" "$installed"; then
    	# Put the working copy back rather than leave the user with nothing.
    	rm -rf "$installed"
    	mv "$aside" "$installed"
    	exit 1
    fi
    # Belt and braces: URLSession sets no quarantine, but a future download path
    # might, and a quarantined bundle would face the user with Gatekeeper.
    xattr -d -r com.apple.quarantine "$installed" 2>/dev/null
    rm -rf "$aside" "$staged"
    open "$installed"
    """
}

enum UpdateError: LocalizedError, Equatable {
    case malformedFeed(String)
    case network(String)
    case unpackFailed(String)
    case signatureRejected(String)
    case digestMismatch
    case adHocCopy
    case notInstalled
    case notWritable(String)
    case wrongPayload(String)

    var errorDescription: String? {
        String(localized: message)
    }

    /// Split from `errorDescription` so the catalog holds the wording and this
    /// holds only which entry to use.
    private var message: LocalizedStringResource {
        switch self {
        case .malformedFeed(let why): return .updateErrorMalformedFeed(why)
        case .network(let why): return .updateErrorNetwork(why)
        case .unpackFailed(let why): return .updateErrorUnpackFailed(why)
        case .signatureRejected(let why): return .updateErrorSignatureRejected(why)
        case .digestMismatch: return .updateErrorDigestMismatch
        case .adHocCopy: return .updateErrorAdHocCopy
        case .notInstalled: return .updateErrorNotInstalled
        case .notWritable(let path): return .updateErrorNotWritable(path)
        case .wrongPayload(let why): return .updateErrorWrongPayload(why)
        }
    }
}
