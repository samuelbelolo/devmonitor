import DevMonitorCore
import SwiftUI

/// The menu bar label of the agents item: the logo of each agent with a session, then their total number of sessions.
public struct AgentMenuBarLabel: View {
    @EnvironmentObject private var store: MonitorStore
    @EnvironmentObject private var versions: VersionStore
    @EnvironmentObject private var clock: GlyphClock

    public init() {}

    public var body: some View {
        let logos = AgentMenuBarItems.shownAgents(store: store, versions: versions).map { agent in
            AgentGlyph.Logo(agent: agent, frame: store.isWorking(agent) ? clock.frame : 0, badge: versions.isOutdated(agent))
        }
        Image(nsImage: AgentGlyph.image(for: logos))
        Text("\(store.agentSessions.count)")
    }
}
