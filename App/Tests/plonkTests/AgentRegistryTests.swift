import Testing
import Foundation
@testable import plonk

struct AgentRegistryTests {

    @Test func registeredAgentIsOnline() {
        let registry = AgentRegistry()
        registry.register(name: "claude-code", version: "2.0", pid: 42)
        #expect(registry.onlineNames() == ["claude-code"])
    }

    @Test func silenceMakesAnAgentOffline() {
        let registry = AgentRegistry()
        let start = Date()
        registry.register(name: "cursor", now: start)
        let later = start.addingTimeInterval(AgentRegistry.presenceTimeout + 1)
        #expect(registry.onlineNames(now: later).isEmpty)
        // The session stays listed, just offline, so the selector can show it.
        #expect(registry.describe(selected: nil, now: later).first?["online"] as? Bool == false)
    }

    @Test func headerTouchRegistersUnknownClients() {
        let registry = AgentRegistry()
        registry.touch(header: "openai-test-agent/0.1", pid: 7)
        #expect(registry.onlineNames() == ["openai-test-agent"])
        #expect(registry.sessions.values.first?.version == "0.1")
    }

    @Test func blankHeadersAreIgnored() {
        let registry = AgentRegistry()
        registry.touch(header: nil, pid: nil)
        registry.touch(header: "", pid: nil)
        registry.register(name: "   ")
        #expect(registry.sessions.isEmpty)
    }

    @Test func sameNameDifferentPidsAreSeparateSessions() {
        let registry = AgentRegistry()
        registry.register(name: "claude-code", pid: 1)
        registry.register(name: "claude-code", pid: 2)
        #expect(registry.sessions.count == 2)
        #expect(registry.onlineNames() == ["claude-code"])
    }

    @Test func describeMarksTheSelectedAgent() {
        let registry = AgentRegistry()
        registry.register(name: "claude-code", pid: 1)
        registry.register(name: "cursor", pid: 2)
        let described = registry.describe(selected: "cursor")
        #expect(described.first { $0["name"] as? String == "cursor" }?["selected"] as? Bool == true)
        #expect(described.first { $0["name"] as? String == "claude-code" }?["selected"] as? Bool == false)
    }

    @Test func onChangeFiresOnlyForNewSessions() {
        let registry = AgentRegistry()
        var changes = 0
        registry.onChange = { changes += 1 }
        registry.register(name: "zed", pid: 3)
        registry.register(name: "zed", pid: 3)
        #expect(changes == 1)
    }
}
