import Foundation

// The half of voice that does not need an agent.
//
// Most of what people say to a window manager is one of a dozen things: put
// this left, zone three, put it back, keep awake an hour, launch my review
// workspace. Sending those to an agent costs a round trip, a running client,
// and a network the Mac may not have — for a sentence whose meaning is fixed.
//
// So the transcript is matched here first, and only what does not match goes to
// the agent. The bar for matching is deliberately high: a false positive
// silently does the wrong thing, while a miss just takes the long road and
// still works. Everything vague — anything with a percentage, an app name, two
// clauses, a word we do not know — falls through on purpose.

enum VoiceCommand: Equatable {
    case preset(Preset)
    case zone(Int)
    /// A zone reached by its name, kept so the HUD can say which name won.
    case namedZone(Int, String)
    case putBack
    case focus(WindowNavigator.Direction)
    /// The front window onto the next display, or the previous one.
    case throwToDisplay(next: Bool)
    /// The front window grown or shrunk by a step.
    case resize(larger: Bool)
    case cycleZone
    case showZones
    /// nil minutes means no limit — awake until it is turned off.
    case awake(minutes: Int?)
    case awakeOff
    case capture(CaptureMode)
    case launchWorkspace(String)

    /// What the HUD says when one of these runs, so the user can tell a local
    /// command from a sentence that went to the agent.
    var announcement: LocalizedStringResource {
        switch self {
        case .preset(let preset): return preset.title
        case .zone(let number): return .voiceAnnounceZone(number)
        case .namedZone(let number, let name): return .voiceAnnounceZoneNamed(number, name)
        case .putBack: return .voiceAnnouncePutBack
        case .focus(let direction): return .voiceAnnounceFocus(String(localized: direction.title))
        case .throwToDisplay(let next): return next ? .shortcutNextDisplay : .shortcutPreviousDisplay
        case .resize(let larger): return larger ? .shortcutLarger : .shortcutSmaller
        case .cycleZone: return .voiceAnnounceNextInZone
        case .showZones: return .voiceAnnounceZones
        case .awake(let minutes):
            guard let minutes else { return .voiceAnnounceKeepAwake }
            return minutes % 60 == 0 && minutes >= 60
                ? .voiceAnnounceAwakeHours(minutes / 60)
                : .voiceAnnounceAwakeMinutes(minutes)
        case .awakeOff: return .voiceAnnounceAwakeOff
        case .capture(let mode): return .voiceAnnounceScreenshot(String(localized: mode.title))
        case .launchWorkspace(let name): return .voiceAnnounceLaunch(name)
        }
    }
}

extension VoiceCommand {

    /// The words that mean "move the front window somewhere". Without one of
    /// these, a bare direction is far more likely to be part of a sentence
    /// meant for the agent ("what is left on my calendar") than a command.
    static let placeVerbs = ["snap", "put", "move", "send", "shove", "throw", "stick",
                                     "drop", "push", "pin"]
    private static let launchVerbs = ["launch", "open", "load", "restore", "bring up", "start"]

    // Spelled-out numbers only. Homophones ("to" for two, "for" for four) were
    // here and had to go: "the zone to the left" then meant zone 2.
    private static let numberWords: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
        "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12,
    ]

    /// A command, or nil when the sentence belongs to the agent.
    ///
    /// `workspaces` are the saved names, so "launch review" only wins when
    /// there is a workspace called review; otherwise the agent hears it and can
    /// ask what was meant. `zoneNames` are the names of the zones on the
    /// screen the front window is on, in zone order and empty where a zone
    /// has none, so "put this in chat" can land in whichever number chat is.
    /// Asked for only once the sentence could mean a zone, since finding the
    /// front window costs a round trip into its app.
    static func parse(_ transcript: String, workspaces: [String] = [],
                      zoneNames: @autoclosure () -> [String] = []) -> VoiceCommand? {
        let text = normalise(transcript)
        guard !text.isEmpty else { return nil }
        let words = Self.words(of: text)

        // A sentence with two halves is a request, not a command: "put this
        // left and open the terminal" has to go somewhere that can do both.
        guard !words.contains("and"), !words.contains("then"), !text.contains(",") else { return nil }
        // Percentages and pixel sizes are layouts, which is the agent's job.
        guard !text.contains("%"), !text.contains("percent") else { return nil }

        if let workspace = workspace(in: text, named: workspaces) { return .launchWorkspace(workspace) }
        if let awake = awake(text, words) { return awake }
        if isPutBack(text) { return .putBack }
        if let shot = capture(text) { return shot }
        if text.contains("show") || text.contains("flash") {
            if text.contains("zone") { return .showZones }
        }
        // A zone named out loud, before the plain-words check: the name is the
        // one word here that need not be in the vocabulary, and everything
        // round it still has to be.
        if let named = namedZone(words, names: zoneNames()) { return .namedZone(named.number, named.name) }
        // Placement acts on whatever is in front, so it may only run on a
        // sentence that does not name anything else. "Move Chrome to the left
        // half" would otherwise move the front window instead of Chrome, which
        // is worse than the round trip to an agent that can find it.
        if isPlain(words) {
            if let thrown = throwToDisplay(words) { return thrown }
            if let sized = resize(words) { return sized }
            if let zone = zone(text, words) { return zone }
            if let preset = preset(text, words) { return .preset(preset) }
        }
        if let focus = focus(text, words) { return focus }
        if isCycle(text) { return .cycleZone }
        return nil
    }

    /// Every word is one this parser knows, so nothing in the sentence can be
    /// the name of an app, a file or a person.
    static func isPlain(_ words: [String]) -> Bool {
        words.allSatisfy { word in
            vocabulary.contains(word) || Int(word) != nil || numberWords[word] != nil
        }
    }

    /// The words that say where on the screen, which a zone named out loud
    /// has to yield to: "the top left" is the corner, whatever a zone is
    /// called.
    static let placementWords: Set<String> = [
        "left", "right", "top", "bottom", "upper", "lower", "up", "down",
        "centre", "center", "middle", "half", "halves", "quarter", "quarters", "corner",
    ]

    static let vocabulary: Set<String> = Set(placeVerbs).union(placementWords).union([
        // what to do, beyond the place verbs
        "make", "maximize", "maximise", "fill", "resize", "go",
        "bigger", "larger", "smaller",
        // what it is done to — never a name, always the front window
        "this", "it", "that", "the", "a", "my", "current", "front", "active",
        "window", "windows", "one",
        // where, beyond the placement words
        "side", "screen", "full", "zone", "display", "monitor",
        "next", "previous", "other",
        // joins and politeness
        "to", "in", "into", "on", "onto", "over", "at", "of", "hand", "please", "now",
    ])

    /// Lowercased, punctuation dropped, runs of spaces collapsed. Dictation
    /// punctuates as it likes, and none of it changes the meaning here.
    static func normalise(_ text: String) -> String {
        let kept = text.lowercased().map { character -> Character in
            if character.isLetter || character.isNumber || character == "%" { return character }
            return character == "," ? "," : " "
        }
        return String(kept).split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - The pieces

    private static func number(in words: [String], after keyword: String) -> Int? {
        guard let index = words.firstIndex(of: keyword), index + 1 < words.count else { return nil }
        return number(words[index + 1])
    }

    static func number(_ word: String) -> Int? {
        if let value = Int(word) { return value }
        return numberWords[word]
    }

    private static func zone(_ text: String, _ words: [String]) -> VoiceCommand? {
        guard text.contains("zone") else { return nil }
        guard let number = number(in: words, after: "zone"), (1...9).contains(number) else { return nil }
        return .zone(number)
    }

    /// The tokens every match here works on. `text` has been through
    /// `normalise`; a name has not, and goes through `words(of: normalise(name))`.
    static func words(of text: String) -> [String] {
        text.split(separator: " ").map(String.init)
    }

    private static func isPutBack(_ text: String) -> Bool {
        text.contains("put it back") || text.contains("put this back") || text.contains("put that back")
            || text.contains("back where it was") || text.contains("undo that")
            || text == "put back" || text == "unsnap"
    }

    private static func isCycle(_ text: String) -> Bool {
        text.contains("next window") || text.contains("cycle") && text.contains("zone")
    }

    private static func focus(_ text: String, _ words: [String]) -> VoiceCommand? {
        guard words.contains("focus") || text.contains("go to the window") else { return nil }
        for direction in WindowNavigator.Direction.allCases where words.contains(direction.rawValue) {
            return .focus(direction)
        }
        if words.contains("above") { return .focus(.up) }
        if words.contains("below") { return .focus(.down) }
        return nil
    }

    private static func capture(_ text: String) -> VoiceCommand? {
        guard text.contains("screenshot") || text.contains("capture the screen")
            || text.contains("grab the screen") else { return nil }
        // A region shot needs a selection, which nobody can make while holding
        // a push-to-talk key, so only the two that finish on their own qualify.
        if text.contains("window") { return .capture(.window) }
        if text.contains("screen") || text == "screenshot" || text.contains("take a screenshot") {
            return .capture(.screen)
        }
        return nil
    }

    private static func awake(_ text: String, _ words: [String]) -> VoiceCommand? {
        let mentionsAwake = text.contains("awake") || text.contains("stay up")
            || text.contains("keep the screen on") || text.contains("don't sleep")
            || text.contains("dont sleep") || text.contains("stop sleeping")
        guard mentionsAwake || text.contains("let it sleep") || text.contains("go to sleep") else {
            return nil
        }
        // "until this build finishes", "when the tests pass" — a condition, and
        // the agent is the only one that can watch for it.
        guard !text.contains("until"), !text.contains("when ") else { return nil }
        let off = text.contains("stop") || text.contains("turn off") || text.contains("let it sleep")
            || text.contains("go to sleep") || text.contains("no longer")
        if off { return .awakeOff }

        // "for an hour", "for two hours", "for 45 minutes", "half an hour".
        if text.contains("half an hour") { return .awake(minutes: 30) }
        if let index = words.firstIndex(where: { $0.hasPrefix("hour") }) {
            let count = index > 0 ? number(words[index - 1]) : nil
            return .awake(minutes: (count ?? 1) * 60)
        }
        if let index = words.firstIndex(where: { $0.hasPrefix("minute") }), index > 0 {
            guard let count = number(words[index - 1]) else { return .awake(minutes: nil) }
            return .awake(minutes: count)
        }
        return .awake(minutes: nil)
    }

    /// The longest saved name that appears in the sentence, next to a verb that
    /// means "open it". Longest so "work notes" beats "work" when both exist.
    ///
    /// Whole words only: on a substring match, a workspace called "work" is
    /// found inside the word "workspace", and every sentence about workspaces
    /// launches it.
    private static func workspace(in text: String, named workspaces: [String]) -> String? {
        guard launchVerbs.contains(where: { text.contains($0) }) else { return nil }
        let words = Self.words(of: text)
        return workspaces
            .filter { name in
                let wanted = Self.words(of: normalise(name))
                guard !wanted.isEmpty, wanted.count <= words.count else { return false }
                return (0...(words.count - wanted.count)).contains {
                    Array(words[$0..<($0 + wanted.count)]) == wanted
                }
            }
            .max { normalise($0).count < normalise($1).count }
    }

    private static func preset(_ text: String, _ words: [String]) -> Preset? {
        let vertical = words.contains("top") || words.contains("upper")
            ? "top" : (words.contains("bottom") || words.contains("lower") ? "bottom" : nil)
        let horizontal = words.contains("left") ? "left" : (words.contains("right") ? "right" : nil)

        let commanded = placeVerbs.contains(where: { words.contains($0) })
        // "left half" and "top right quarter" are unambiguous without a verb;
        // a bare "left" is not.
        let shaped = words.contains("half") || words.contains("quarter") || words.contains("corner")

        if text.contains("maximize") || text.contains("maximise") || text.contains("full screen")
            || text.contains("fill the screen") {
            return .maximize
        }
        if (words.contains("centre") || words.contains("center")) && (commanded || words.count <= 3) {
            return .center
        }
        guard commanded || shaped else { return nil }

        switch (vertical, horizontal) {
        case ("top", "left"): return .topLeft
        case ("top", "right"): return .topRight
        case ("bottom", "left"): return .bottomLeft
        case ("bottom", "right"): return .bottomRight
        case ("top", nil): return .topHalf
        case ("bottom", nil): return .bottomHalf
        case (nil, "left"): return .leftHalf
        case (nil, "right"): return .rightHalf
        default: return nil
        }
    }
}
