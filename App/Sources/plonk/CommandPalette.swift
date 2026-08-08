import Foundation

// What ⌘K can run.
//
// The app already has one list of everything it can do — AppActions — and the
// only way to reach most of it was to know a shortcut or to be an agent. A
// command is that same verb with a name attached, so a person can type it.

struct PlonkCommand: Identifiable {
    let id: String
    let title: String
    /// The heading it is filed under in the palette.
    let group: String
    /// The shortcut, already split into caps, or empty when it has none.
    var keys: [String] = []
    let run: () -> Void
}

extension Array where Element == PlonkCommand {
    /// The commands matching `query`, best first.
    ///
    /// Subsequence matching, not substring: "szn" finds "Snap to zone" the way
    /// every other palette does, and typing the words in order still works
    /// because a run of adjacent letters scores higher than a scattered one.
    func matching(_ query: String) -> [PlonkCommand] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return self }
        return compactMap { command -> (PlonkCommand, Int)? in
            guard let score = Self.score(command.title.lowercased(), needle) else { return nil }
            return (command, score)
        }
        .sorted { $0.1 > $1.1 }
        .map(\.0)
    }

    /// Nil when `needle` is not a subsequence of `haystack`. Otherwise a score
    /// that rewards matching at the start of a word and matching consecutively,
    /// which is what makes the obvious command come first.
    private static func score(_ haystack: String, _ needle: String) -> Int? {
        var total = 0
        var streak = 0
        var index = haystack.startIndex
        for character in needle {
            guard let found = haystack[index...].firstIndex(of: character) else { return nil }
            // The character before the match, not the match itself: that is what
            // says whether this letter starts a word.
            let before = found == haystack.startIndex ? nil : haystack[haystack.index(before: found)]
            let atWordStart = before == nil || before == " " || before == "-" || before == "\u{201C}"
            let adjacent = found == index && index != haystack.startIndex
            streak = adjacent ? streak + 1 : 0
            total += 1 + streak * 3 + (atWordStart ? 6 : 0)
            index = haystack.index(after: found)
        }
        // A short title that used all of itself beats a long one that did not.
        return total * 100 - haystack.count
    }
}
