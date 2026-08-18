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

extension PlonkCommand {
    /// The row that hands what was typed to an agent instead of matching it
    /// against anything. It is what makes the palette answer a sentence — "put
    /// the browser left and the terminal top right" is not a command and never
    /// will be, but it is the kind of thing people want to type here.
    ///
    /// Nil for an empty query, because a palette offering to send nothing is
    /// offering a mistake.
    static func ask(_ query: String, agent: String?, run: @escaping () -> Void) -> PlonkCommand? {
        let prompt = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return nil }
        let named = (agent ?? "").trimmingCharacters(in: .whitespaces)
        // Named when one is selected, so it is obvious where the sentence went;
        // vague when none is, because that is the honest state and the HUD says
        // the rest when it fails.
        let who = named.isEmpty ? String(localized: .paletteTheAgent) : named
        return PlonkCommand(id: "agent.ask", title: String(localized: .paletteAsk(who, prompt)),
                            group: String(localized: .paletteGroupAgent), keys: ["⌘", "return"], run: run)
    }
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
