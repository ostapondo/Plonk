import Foundation

// Apps Plonk leaves alone. Drag snapping and the placement hotkeys both act on
// whatever window happens to be under the cursor or in front, which is wrong
// for games, remote desktops and anything that manages its own geometry.
//
// An entry matches when it appears anywhere in the app's name or bundle
// identifier, case-insensitively, so "steam" covers both Steam and Steam
// Helper. Explicit placement — the HTTP API, the MCP tools, launching a
// workspace — is never filtered: those name the window on purpose.

enum AppExclusions {
    /// One pattern per line, as the settings field stores them.
    static func parse(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func text(from patterns: [String]) -> String {
        patterns.joined(separator: "\n")
    }

    static func matches(name: String, bundleID: String?, patterns: [String]) -> Bool {
        guard !patterns.isEmpty else { return false }
        let haystacks = [name.lowercased(), (bundleID ?? "").lowercased()].filter { !$0.isEmpty }
        guard !haystacks.isEmpty else { return false }
        for pattern in patterns {
            let needle = pattern.trimmingCharacters(in: .whitespaces).lowercased()
            guard !needle.isEmpty else { continue }
            if haystacks.contains(where: { $0.contains(needle) }) { return true }
        }
        return false
    }
}
