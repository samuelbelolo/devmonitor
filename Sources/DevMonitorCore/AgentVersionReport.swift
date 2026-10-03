import Foundation

/// The installed and latest published versions of one agent.
public struct AgentVersionReport: Identifiable, Sendable {
    public let agent: Agent
    public let installed: VersionNumber?
    /// Nil when the agent has no public registry, the check is turned off, or the registry did not answer.
    public let latest: VersionNumber?

    public init(agent: Agent, installed: VersionNumber?, latest: VersionNumber?) {
        self.agent = agent
        self.installed = installed
        self.latest = latest
    }

    public var id: String { agent.rawValue }
    /// Returns the sessions running an older version than the one restarting them would load: the installed
    /// command line tool, or for a session an editor extension runs, the newest version of that extension.
    /// @example report.sessionsToRestart(among: store.sessions(of: .claude)).count // 1
    public func sessionsToRestart(among sessions: [AgentSession], listing: (String) -> [String] = EditorExtension.directoryListing) -> [AgentSession] {
        sessions.filter { session in
            guard session.agent == agent, let running = session.version else { return false }
            let path = session.process.executablePath
            let loaded = EditorExtension.contains(path) ? EditorExtension.newestVersion(of: path, listing: listing) : installed
            return loaded.map { running < $0 } == true
        }
    }

    /// Whether a newer version than the installed one is published.
    public var isOutdated: Bool {
        guard let installed, let latest else { return false }
        return installed < latest
    }
}
