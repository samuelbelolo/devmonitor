import Foundation

/// A coding agent whose sessions the monitor recognises and never signals.
/// A new case also needs its menu bar item, listed by hand in `DevMonitorApp.body`.
public enum Agent: String, CaseIterable, Equatable, Sendable {
    case claude
    case codex
    case gemini
    case aider
    case opencode
    case cursorAgent
    case amp

    /// The name shown in "started by …".
    public var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .gemini: "Gemini"
        case .aider: "Aider"
        case .opencode: "opencode"
        case .cursorAgent: "Cursor Agent"
        case .amp: "Amp"
        }
    }

    /// The command name of the agent, as an executable or a script.
    var command: String {
        self == .cursorAgent ? "cursor-agent" : rawValue
    }

    /// Path fragments of the package or install folder the agent runs from.
    private var packagePaths: [String] {
        switch self {
        case .claude: ["/claude/versions/", "/@anthropic-ai/claude-code/"]
        case .codex: ["/@openai/codex/"]
        case .gemini: ["/@google/gemini-cli/"]
        case .opencode: ["/opencode-ai/"]
        case .amp: ["/@sourcegraph/amp/"]
        case .aider, .cursorAgent: []
        }
    }

    private static let interpreters: Set<String> = ["node", "bun", "deno"]

    /// Returns the agent a process is a session of: by its executable, its first argument, or the script an interpreter runs.
    /// @example Agent.running(nodeRunningCodexJs) // .codex
    public static func running(_ process: ProcessSnapshot) -> Agent? {
        let name = process.name
        let argv0 = ((process.arguments.first ?? "") as NSString).lastPathComponent
        let script = interprets(process) ? process.arguments.dropFirst().first { !$0.hasPrefix("-") } : nil
        let scriptName = script.map { (($0 as NSString).lastPathComponent as NSString).deletingPathExtension }
        return allCases.first { agent in
            name == agent.command || argv0 == agent.command || scriptName == agent.command
                || agent.packagePaths.contains { process.executablePath.contains($0) || script?.contains($0) == true }
        }
    }

    /// Whether a process is an interpreter running a script: node, bun, deno or Python. Framework Python runs as
    /// "Python", hence the lowercase comparison.
    /// @example Agent.interprets(nodeRunningCodexJs) // true
    static func interprets(_ process: ProcessSnapshot) -> Bool {
        interpreters.contains(process.name) || process.name.lowercased().hasPrefix("python")
    }
}
