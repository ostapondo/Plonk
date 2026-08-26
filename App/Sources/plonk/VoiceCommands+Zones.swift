import Foundation

// A zone named out loud. Split from VoiceCommands, which is at the line
// limit; the vocabulary and the plain-words test it leans on live there.

extension VoiceCommand {
    /// "put this in chat", "snap it to the build log", "zone chat": a place
    /// verb or the word zone, the name as whole words in order, and round it
    /// nothing but words the parser knows. Longest name first, so "build
    /// log" beats a zone called "log" when both exist. The number is 1-based,
    /// the way `.zone` is spoken and the keys are labelled.
    ///
    /// A name yields to anything else in the sentence that says where: a
    /// placement word or a number. "The top left" is the corner and "zone
    /// two" is the second zone whatever the zones are called, and "move
    /// terminal to the left" names an app, which is the agent's to move. A
    /// name that is itself a number, spelled or not, is never matched.
    static func namedZone(_ words: [String], names: [String]) -> (number: Int, name: String)? {
        guard words.contains("zone") || placeVerbs.contains(where: words.contains) else { return nil }
        let candidates = names.enumerated()
            .map { (number: $0.offset + 1, name: $0.element, words: Self.words(of: normalise($0.element))) }
            .filter { !$0.words.isEmpty && !$0.words.allSatisfy { number($0) != nil } }
            .sorted { $0.words.count > $1.words.count }
        for candidate in candidates {
            guard let range = words.firstRange(of: candidate.words) else { continue }
            let rest = Array(words[..<range.lowerBound]) + Array(words[range.upperBound...])
            guard isPlain(rest),
                  !rest.contains(where: placementWords.contains),
                  !rest.contains(where: { number($0) != nil }) else { continue }
            return (candidate.number, candidate.name)
        }
        return nil
    }
}
