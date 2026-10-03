import Foundation

/// Where each agent publishes its versions, and the command that updates it.
public enum AgentRelease {
    /// A public registry and the name of the agent's package in it.
    private enum Registry {
        case npm(String)
        case pypi(String)
    }

    /// Returns where the agent publishes its versions, or nil when it has no public registry.
    /// @example registry(for: .aider) // .pypi("aider-chat")
    private static func registry(for agent: Agent) -> Registry? {
        switch agent {
        case .claude: .npm("@anthropic-ai/claude-code")
        case .codex: .npm("@openai/codex")
        case .gemini: .npm("@google/gemini-cli")
        case .opencode: .npm("opencode-ai")
        case .amp: .npm("@sourcegraph/amp")
        case .aider: .pypi("aider-chat")
        case .cursorAgent: nil
        }
    }

    /// Returns the address that answers with the latest published version, or nil when the agent has no public registry.
    /// @example AgentRelease.latestURL(for: .codex) // https://registry.npmjs.org/@openai/codex/latest
    public static func latestURL(for agent: Agent) -> URL? {
        switch registry(for: agent) {
        case .npm(let package): URL(string: "https://registry.npmjs.org/\(package)/latest")
        case .pypi(let package): URL(string: "https://pypi.org/pypi/\(package)/json")
        case nil: nil
        }
    }

    /// Reads the latest version from the registry's answer: `version` for npm, `info.version` for PyPI.
    /// @example AgentRelease.latest(from: npmAnswer, for: .codex)?.text // "0.161.0"
    public static func latest(from data: Data, for agent: Agent) -> VersionNumber? {
        guard let registry = registry(for: agent), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let fields: [String: Any]? = switch registry {
        case .npm: json
        case .pypi: json["info"] as? [String: Any]
        }
        return (fields?["version"] as? String).flatMap { VersionNumber(parsing: $0) }
    }

    /// Returns the command that updates the agent, as its own documentation gives it.
    /// @example AgentRelease.updateCommand(for: .claude) // "claude update"
    public static func updateCommand(for agent: Agent) -> String {
        switch agent {
        case .claude: "claude update"
        case .codex: "codex update"
        case .gemini: "npm install -g @google/gemini-cli@latest"
        case .aider: "aider --upgrade"
        case .opencode: "opencode upgrade"
        case .cursorAgent: "cursor-agent update"
        case .amp: "amp update"
        }
    }
}
