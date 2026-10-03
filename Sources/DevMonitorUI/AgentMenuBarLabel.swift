import DevMonitorCore
import SwiftUI

/// The menu bar label of one agent: its logo and its number of sessions.
public struct AgentMenuBarLabel: View {
    let agent: Agent
    @EnvironmentObject private var store: MonitorStore
    @EnvironmentObject private var versions: VersionStore
    @EnvironmentObject private var clock: GlyphClock

    public init(agent: Agent) {
        self.agent = agent
    }

    public var body: some View {
        let isWorking = store.isWorking(agent)
        Image(nsImage: AgentGlyph.image(for: agent, frame: isWorking ? clock.frame : 0, badge: versions.isOutdated(agent)))
        Text("\(store.sessions(of: agent).count)")
    }
}
