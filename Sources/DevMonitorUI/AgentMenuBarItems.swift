import DevMonitorCore
import SwiftUI

/// Decides which agents' logos the agents menu bar item shows.
@MainActor
public enum AgentMenuBarItems {
    /// Returns the agents with a session, in the order of `Agent.allCases`; when none has one, the first agent
    /// installed, so the agents window stays one click away.
    /// @example AgentMenuBarItems.shownAgents(store: store, versions: versions) // [.claude, .codex] while both run
    public static func shownAgents(store: MonitorStore, versions: VersionStore) -> [Agent] {
        let running = Agent.allCases.filter { !store.sessions(of: $0).isEmpty }
        return running.isEmpty ? [versions.installedAgents.first ?? .claude] : running
    }
}
