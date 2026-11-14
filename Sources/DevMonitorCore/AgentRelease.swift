import Foundation

/// Where each agent publishes its versions, and the command that updates it.
public enum AgentRelease {
    /// A public registry and the name of the agent's package in it.
    private enum Registry {
        case npm(String)
        case pypi(String)
        /// The channel Claude Code's own installer and `claude update` read: one line of text, the version.
        case claudeInstaller
    }

    /// The folder Claude Code's own installer keeps its versions in.
    private static let claudeInstallerFolder = "/claude/versions/"

    /// Returns where the agent publishes its versions, or nil when it has no public registry. `executable` is the
    /// installed command with its links followed: a Claude Code set up by its own installer is updated from the
    /// installer's channel, which gets a version some time after npm does.
    /// @example registry(for: .aider, executable: nil) // .pypi("aider-chat")
    private static func registry(for agent: Agent, executable: String?) -> Registry? {
        switch agent {
        case .claude: executable?.contains(claudeInstallerFolder) == true ? .claudeInstaller : .npm("@anthropic-ai/claude-code")
        case .codex: .npm("@openai/codex")
        case .gemini: .npm("@google/gemini-cli")
        case .opencode: .npm("opencode-ai")
        case .amp: .npm("@sourcegraph/amp")
        case .aider: .pypi("aider-chat")
        case .cursorAgent: nil
        }
    }

    /// Returns the address that answers with the latest published version, or nil when the agent has no public
    /// registry; `executable` is the installed command with its links followed, when it is known.
    /// @example AgentRelease.latestURL(for: .codex) // https://registry.npmjs.org/@openai/codex/latest
    public static func latestURL(for agent: Agent, executable: String? = nil) -> URL? {
        switch registry(for: agent, executable: executable) {
        case .npm(let package): URL(string: "https://registry.npmjs.org/\(package)/latest")
        case .pypi(let package): URL(string: "https://pypi.org/pypi/\(package)/json")
        case .claudeInstaller: URL(string: "https://downloads.claude.ai/claude-code-releases/latest")
        case nil: nil
        }
    }

    /// Reads the latest version from the answer of the address `latestURL` gave for the same agent and command:
    /// `version` for npm, `info.version` for PyPI, the whole text for Claude Code's installer.
    /// @example AgentRelease.latest(from: npmAnswer, for: .codex)?.text // "0.161.0"
    public static func latest(from data: Data, for agent: Agent, executable: String? = nil) -> VersionNumber? {
        guard let registry = registry(for: agent, executable: executable) else { return nil }
        if case .claudeInstaller = registry { return wholeVersion(in: data) }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let fields: [String: Any]? = switch registry {
        case .npm, .claudeInstaller: json
        case .pypi: json["info"] as? [String: Any]
        }
        return (fields?["version"] as? String).flatMap { VersionNumber(parsing: $0) }
    }

    /// Returns the version an answer consists of; nil when it holds anything else, such as an error page.
    /// @example wholeVersion(in: Data("2.1.325\n".utf8))?.text // "2.1.325"
    private static func wholeVersion(in data: Data) -> VersionNumber? {
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: #"^\d+(\.\d+)+$"#, options: .regularExpression) != nil else { return nil }
        return VersionNumber(parsing: text)
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
