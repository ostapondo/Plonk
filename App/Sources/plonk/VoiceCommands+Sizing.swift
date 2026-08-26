import Foundation

// Voice commands that move a window between displays or change its size.
// Kept beside the main parser so that file stays below the line limit.

extension VoiceCommand {
    /// "throw it to the next screen", "put this on the other monitor": a
    /// place verb, a display by some name, and which one.
    static func throwToDisplay(_ words: [String]) -> VoiceCommand? {
        guard placeVerbs.contains(where: words.contains),
              words.contains(where: { ["display", "screen", "monitor"].contains($0) }) else { return nil }
        if words.contains("next") || words.contains("other") { return .throwToDisplay(next: true) }
        if words.contains("previous") { return .throwToDisplay(next: false) }
        return nil
    }

    /// "make it bigger", "smaller". Every word is one the parser knows, so
    /// "make Chrome bigger" has already gone to the agent.
    static func resize(_ words: [String]) -> VoiceCommand? {
        if words.contains("bigger") || words.contains("larger") { return .resize(larger: true) }
        if words.contains("smaller") { return .resize(larger: false) }
        return nil
    }
}
