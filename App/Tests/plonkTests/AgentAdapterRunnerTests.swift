import Testing
@testable import plonk

struct AgentAdapterRunnerTests {
    @Test func capturesTheLastErrorWithoutBlockingOnVerboseOutput() async throws {
        let runner = AgentAdapterRunner()
        let adapter = AgentAdapter(
            name: "fixture",
            command: "yes noise | head -c 100000 >&2; printf '\\nlast-error\\n' >&2; exit 7; : {prompt}"
        )
        let result = await withCheckedContinuation { continuation in
            runner.run(adapter, prompt: "hello") { continuation.resume(returning: $0) }
        }
        guard case .finished(let finished) = result else {
            Issue.record("adapter did not run")
            return
        }
        #expect(finished.status == 7)
        #expect(finished.lastError == "last-error")
    }
}
