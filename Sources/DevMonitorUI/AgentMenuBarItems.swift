import DevMonitorCore
import SwiftUI

/// Decides which agents get a menu bar item.
@MainActor
public enum AgentMenuBarItems {
    /// Whether an agent shows in the menu bar: when it has a session, or, when no agent has any, the first one
    /// installed, so the agents window stays one click away.
    /// @example AgentMenuBarItems.isShown(.codex, store: store, versions: versions) // true while a Codex session runs
    public static func isShown(_ agent: Agent, store: MonitorStore, versions: VersionStore) -> Bool {
        if !store.sessions(of: agent).isEmpty { return true }
        guard store.agentSessions.isEmpty else { return false }
        return agent == (versions.installedAgents.first ?? .claude)
    }
}
