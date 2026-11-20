import Foundation

// The text of the Agents & MCP and Voice pages. English values live in
// Resources/en.lproj/Localizable.strings.

extension LocalizedStringResource {
    static let aiAgents = Self.key("ai.agents")
    static let aiAgentsHelp = Self.key("ai.agentsHelp")
    static let aiNoAgents = Self.key("ai.noAgents")
    static let aiActiveAgent = Self.key("ai.activeAgent")
    static let aiAnyAgent = Self.key("ai.anyAgent")
    static let aiExclusive = Self.key("ai.exclusive")
    static let aiExclusiveHelp = Self.key("ai.exclusiveHelp")
    static let aiLocalApi = Self.key("ai.localApi")
    static let aiAnyMcpClient = Self.key("ai.anyMcpClient")
    static let aiConnect = Self.key("ai.connect")
    static let aiConnectHelp = Self.key("ai.connectHelp")
    static let aiTrySaying = Self.key("ai.trySaying")
    static let aiClickToCopy = Self.key("ai.clickToCopy")
    static let aiCopied = Self.key("ai.copied")

    static func aiAgentOffline(_ name: String) -> LocalizedStringResource {
        Self.key("ai.agentOffline \(name)")
    }

    /// What to try saying to an agent. Copied to the clipboard on click, so
    /// these are sentences a translator should rewrite, not transliterate.
    static let aiExamples: [LocalizedStringResource] = [
        Self.key("ai.example1"),
        Self.key("ai.example2"),
        Self.key("ai.example3"),
        Self.key("ai.example4"),
        Self.key("ai.example5"),
        Self.key("ai.example6"),
        Self.key("ai.example7"),
    ]

    static let voicePushToTalk = Self.key("voice.pushToTalk")
    static let voicePushToTalkHelp = Self.key("voice.pushToTalkHelp")
    static let voiceRunCommonHere = Self.key("voice.runCommonHere")
    static let voiceRunCommonHereHelp = Self.key("voice.runCommonHereHelp")
    static let voiceStraightToPlonk = Self.key("voice.straightToPlonk")
    static let voiceStraightToPlonkHelp = Self.key("voice.straightToPlonkHelp")
    static let voiceToTheAgent = Self.key("voice.toTheAgent")
    static let voiceToTheAgentHelp = Self.key("voice.toTheAgentHelp")

    /// Phrases the local recogniser understands, quoted as they are shown.
    static let voiceExamples: [LocalizedStringResource] = [
        Self.key("voice.example1"),
        Self.key("voice.example2"),
        Self.key("voice.example3"),
        Self.key("voice.example4"),
        Self.key("voice.example5"),
        Self.key("voice.example6"),
    ]

    static let voiceAnnouncePutBack = Self.key("voice.announce.putBack")
    static let voiceAnnounceNextInZone = Self.key("voice.announce.nextInZone")
    static let voiceAnnounceZones = Self.key("voice.announce.zones")
    static let voiceAnnounceKeepAwake = Self.key("voice.announce.keepAwake")
    static let voiceAnnounceAwakeOff = Self.key("voice.announce.awakeOff")

    static func voiceAnnounceZone(_ number: Int) -> LocalizedStringResource {
        Self.key("voice.announce.zone \(number)")
    }

    static func voiceAnnounceZoneNamed(_ number: Int, _ name: String) -> LocalizedStringResource {
        Self.key("voice.announce.zoneNamed \(number) \(name)")
    }

    static func voiceAnnounceFocus(_ direction: String) -> LocalizedStringResource {
        Self.key("voice.announce.focus \(direction)")
    }

    static func voiceAnnounceAwakeHours(_ hours: Int) -> LocalizedStringResource {
        Self.key("voice.announce.awakeHours \(hours)")
    }

    static func voiceAnnounceAwakeMinutes(_ minutes: Int) -> LocalizedStringResource {
        Self.key("voice.announce.awakeMinutes \(minutes)")
    }

    static func voiceAnnounceScreenshot(_ mode: String) -> LocalizedStringResource {
        Self.key("voice.announce.screenshot \(mode)")
    }

    static func voiceAnnounceLaunch(_ workspace: String) -> LocalizedStringResource {
        Self.key("voice.announce.launch \(workspace)")
    }
}
