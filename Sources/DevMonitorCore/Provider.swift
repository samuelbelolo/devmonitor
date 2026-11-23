import Foundation

/// A provider whose accounts DevMonitor follows: Anthropic's Claude, or OpenAI's Codex (a ChatGPT account).
public enum Provider: String, Codable, Sendable, CaseIterable {
    case claude
    case codex

    /// The agent the provider's accounts run, whose logo stands for them.
    /// @example Provider.codex.agent // .codex
    public var agent: Agent {
        switch self {
        case .claude: .claude
        case .codex: .codex
        }
    }
}
