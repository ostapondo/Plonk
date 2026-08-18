import Foundation

/// A command-line agent Plonk can start on demand — the fallback channel for
/// clients that hold no live MCP session or cannot receive sampling requests.
struct AgentAdapter: Codable {
    var name: String
    var command: String

    /// The environment variable the prompt travels in. Substituting the text
    /// into the command line cannot be made safe — a template that happens to
    /// quote {prompt} would break any escaping we applied — so the shell never
    /// sees the words at all, only the name of a variable holding them.
    static let promptVariable = "PLONK_PROMPT"

    /// The command to run for `prompt`, with the prompt supplied out of band.
    /// `{prompt}` becomes a reference to the variable; a template without it
    /// gets one appended. Quotes people naturally put around the placeholder
    /// are consumed with it — the substitution already quotes itself, and
    /// leaving theirs would either block expansion (single quotes, so the tool
    /// would receive the literal text `$PLONK_PROMPT`) or nest pointlessly.
    static func invocation(command: String, prompt: String) -> (command: String, environment: [String: String]) {
        let reference = "\"$\(promptVariable)\""
        var line = command
        if line.contains("{prompt}") {
            for quoted in ["'{prompt}'", "\"{prompt}\"", "{prompt}"] {
                line = line.replacingOccurrences(of: quoted, with: reference)
            }
        } else {
            line += " " + reference
        }
        return (line, [promptVariable: prompt])
    }
}
