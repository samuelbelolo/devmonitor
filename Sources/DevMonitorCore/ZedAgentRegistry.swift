import Foundation

/// The agent adapters Zed downloads from its ACP registry: each version lives in its own `v_<version>_…` folder,
/// whose number is the adapter's (claude-agent-acp 0.108.0), not the bundled agent's (Claude Code 2.1.326).
public enum ZedAgentRegistry {
    private static let marker = "/Zed/external_agents/registry/"

    /// Whether a binary comes from an adapter Zed downloaded.
    /// @example ZedAgentRegistry.contains("/Users/me/Library/Application Support/Zed/external_agents/registry/claude-acp/v_0.108.0_a_b/claude") // true
    public static func contains(_ executablePath: String) -> Bool {
        executablePath.contains(marker)
    }

    /// Returns the newest adapter version downloaded beside the one a binary comes from; nil when none can be read.
    /// Zed starts its next session of that agent on this version.
    /// @example ZedAgentRegistry.newestVersion(of: binaryIn0_107_2)?.text // "0.108.0"
    public static func newestVersion(of executablePath: String, listing: (String) -> [String] = EditorExtension.directoryListing) -> VersionNumber? {
        guard let range = executablePath.range(of: marker) else { return nil }
        let rest = executablePath[range.upperBound...].split(separator: "/")
        guard let agent = rest.first else { return nil }
        let directory = String(executablePath[..<range.upperBound]) + agent
        return listing(directory)
            .filter { $0.hasPrefix("v_") }
            .compactMap { VersionNumber(parsing: String($0.dropFirst(2).prefix { $0 != "_" })) }
            .max()
    }
}
