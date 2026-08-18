import Testing
import Foundation
@testable import plonk

struct ReleaseVersionTests {

    @Test func theTagsGithubWritesParseTheSameAsAPlainVersion() {
        #expect(ReleaseVersion("v0.0.3") == ReleaseVersion("0.0.3"))
        #expect(ReleaseVersion("V1.2")?.parts == [1, 2])
    }

    @Test func orderingIsNumericRatherThanLexical() {
        // The whole point: "0.0.10" sorts below "0.0.9" as text.
        #expect(ReleaseVersion("0.0.9")! < ReleaseVersion("0.0.10")!)
        #expect(ReleaseVersion("0.10.0")! > ReleaseVersion("0.9.9")!)
        #expect(ReleaseVersion("1.0")! > ReleaseVersion("0.99.99")!)
    }

    @Test func aMissingComponentCountsAsZero() {
        #expect(ReleaseVersion("1.0") == ReleaseVersion("1.0.0"))
        #expect(ReleaseVersion("1.0.1")! > ReleaseVersion("1.0")!)
    }

    @Test func somethingWithoutANumberIsNotAVersion() {
        #expect(ReleaseVersion("") == nil)
        #expect(ReleaseVersion("latest") == nil)
        #expect(ReleaseVersion("v") == nil)
    }
}

struct ReleaseParsingTests {

    private func feed(tag: String = "v0.0.4", assets: [[String: Any]]? = nil,
                      extra: [String: Any] = [:]) throws -> Data {
        var root: [String: Any] = [
            "tag_name": tag,
            "html_url": "https://github.com/ostapondo/Plonk/releases/tag/\(tag)",
            "body": "Fixes things.",
            "assets": assets ?? [[
                "name": "Plonk-0.0.4.zip",
                "browser_download_url": "https://github.com/ostapondo/Plonk/releases/download/\(tag)/Plonk-0.0.4.zip",
                "size": 2_400_000,
            ]],
        ]
        root.merge(extra) { _, new in new }
        return try JSONSerialization.data(withJSONObject: root)
    }

    @Test func aNormalReleaseYieldsItsZipAndVersion() throws {
        let release = try Release.parse(feed())
        #expect(release.version == ReleaseVersion("0.0.4"))
        #expect(release.downloadURL.lastPathComponent == "Plonk-0.0.4.zip")
        #expect(release.size == 2_400_000)
        #expect(release.notes == "Fixes things.")
    }

    @Test func draftsAndPrereleasesAreNotOffered() {
        #expect(throws: UpdateError.self) { try Release.parse(feed(extra: ["draft": true])) }
        #expect(throws: UpdateError.self) { try Release.parse(feed(extra: ["prerelease": true])) }
    }

    @Test func aReleaseWithoutAZipIsRejectedRatherThanGuessedAt() {
        let assets = [["name": "Plonk-0.0.4.dmg",
                       "browser_download_url": "https://example.invalid/Plonk.dmg"]]
        #expect(throws: UpdateError.self) { try Release.parse(feed(assets: assets)) }
        #expect(throws: UpdateError.self) { try Release.parse(feed(assets: [])) }
    }

    /// A second zip on a release must not be able to redirect every installed
    /// copy just by having been uploaded first.
    @Test func theAppArchiveWinsOverAnotherZipListedBeforeIt() throws {
        let assets: [[String: Any]] = [
            ["name": "dSYMs.zip", "browser_download_url": "https://example.invalid/dSYMs.zip"],
            ["name": "Plonk-0.0.4.zip", "browser_download_url": "https://example.invalid/Plonk-0.0.4.zip"],
        ]
        let release = try Release.parse(feed(assets: assets))
        #expect(release.downloadURL.lastPathComponent == "Plonk-0.0.4.zip")
    }

    @Test func severalZipsAndNoneNamedForTheAppIsRefusedRatherThanGuessed() {
        let assets: [[String: Any]] = [
            ["name": "dSYMs.zip", "browser_download_url": "https://example.invalid/dSYMs.zip"],
            ["name": "sources.zip", "browser_download_url": "https://example.invalid/sources.zip"],
        ]
        #expect(throws: UpdateError.self) { try Release.parse(feed(assets: assets)) }
    }

    @Test func aLoneUnnamedZipIsStillAccepted() throws {
        let assets = [["name": "plonk.zip", "browser_download_url": "https://example.invalid/plonk.zip"]]
        #expect(try Release.parse(feed(assets: assets)).downloadURL.lastPathComponent == "plonk.zip")
    }

    @Test func anUnusableTagIsRejected() {
        #expect(throws: UpdateError.self) { try Release.parse(feed(tag: "nightly")) }
        #expect(throws: UpdateError.self) { try Release.parse(Data("not json".utf8)) }
    }

    @Test func aMissingSizeIsZeroRatherThanAFailure() throws {
        let assets = [["name": "Plonk-0.0.4.zip",
                       "browser_download_url": "https://example.invalid/Plonk-0.0.4.zip"]]
        #expect(try Release.parse(feed(assets: assets)).size == 0)
    }

    @Test func theAssetDigestIsCarriedThrough() throws {
        let hash = String(repeating: "ab", count: 32)
        let assets = [["name": "Plonk-0.0.4.zip",
                       "browser_download_url": "https://example.invalid/Plonk-0.0.4.zip",
                       "digest": "sha256:\(hash.uppercased())"]]
        #expect(try Release.parse(feed(assets: assets)).digest == hash)
    }

    /// Releases cut before GitHub published a digest still have to install,
    /// and they are checked the way they always were.
    @Test func aReleaseWithoutADigestStillParses() throws {
        #expect(try Release.parse(feed()).digest == nil)
    }
}

struct ReleaseDigestTests {

    @Test func onlyASha256OfTheRightShapeIsAccepted() {
        let hash = String(repeating: "0f", count: 32)
        #expect(Release.hexSHA256(from: "sha256:\(hash)") == hash)
        #expect(Release.hexSHA256(from: "SHA256:\(hash)") == hash)
    }

    /// A digest that cannot be read has to come back nil rather than an empty
    /// or truncated string: the caller skips the check when there is none, so
    /// anything short of a real hash must not present itself as one.
    @Test func anythingElseIsNoDigestRatherThanABadOne() {
        let hash = String(repeating: "0f", count: 32)
        #expect(Release.hexSHA256(from: nil) == nil)
        #expect(Release.hexSHA256(from: 42) == nil)
        #expect(Release.hexSHA256(from: "") == nil)
        #expect(Release.hexSHA256(from: hash) == nil, "no algorithm named")
        #expect(Release.hexSHA256(from: "sha512:\(hash)") == nil)
        #expect(Release.hexSHA256(from: "sha256:") == nil)
        #expect(Release.hexSHA256(from: "sha256:\(hash.dropLast())") == nil, "too short")
        #expect(Release.hexSHA256(from: "sha256:\(hash.dropLast())zz") == nil, "not hex")
    }
}

struct InstallScriptTests {

    /// The script runs after the app is gone, so a mistake in it is only ever
    /// found by a user whose copy has already been moved aside.
    @Test func theScriptTakesItsPathsAsArgumentsNotAsText() {
        let script = Release.installScript
        #expect(script.contains("pid=$1"))
        #expect(script.contains("staged=$2"))
        #expect(script.contains("installed=$3"))
    }

    @Test func theOldCopyGoesBackWhenTheNewOneCannotBeWritten() {
        let script = Release.installScript
        // The rollback branch, and the order that makes it possible.
        #expect(script.contains("mv \"$installed\" \"$aside\""))
        #expect(script.contains("mv \"$aside\" \"$installed\""))
        #expect(script.contains("if ! ditto \"$staged\" \"$installed\""))
    }

    @Test func itWaitsForTheRunningCopyAndGivesUpRatherThanSwappingUnderIt() {
        let script = Release.installScript
        #expect(script.contains("kill -0 \"$pid\""))
        #expect(script.contains("exit 1"))
        #expect(script.contains("open \"$installed\""))
    }

    /// Every path the script touches is quoted, or a Plonk.app under a folder
    /// with a space in it would be torn in half.
    @Test func everyPathExpansionIsQuoted() {
        for line in Release.installScript.split(separator: "\n") {
            let text = String(line)
            guard !text.hasPrefix("#") else { continue }
            for variable in ["$installed", "$staged", "$aside", "$pid"] {
                guard let range = text.range(of: variable) else { continue }
                let before = text[..<range.lowerBound].last
                #expect(before == "\"", "unquoted \(variable) in: \(text)")
            }
        }
    }
}
