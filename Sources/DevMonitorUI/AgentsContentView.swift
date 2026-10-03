import DevMonitorCore
import SwiftUI

/// The window opened from an agent's menu bar item: the sessions, where they run, and the agents' versions.
public struct AgentsContentView: View {
    /// The agent whose menu bar item opens this window.
    let agent: Agent
    @EnvironmentObject private var store: MonitorStore
    @EnvironmentObject private var versions: VersionStore
    @EnvironmentObject private var clock: GlyphClock

    /// The glyphs Claude Code itself cycles through while it thinks.
    private static let thinking = ["·", "✢", "✳", "✶", "✻", "✽", "✻", "✶", "✳", "✢"]

    public init(agent: Agent) {
        self.agent = agent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(store.agentSessions.count)").font(.system(size: 32, weight: .bold)).monospacedDigit()
                if store.workingCount > 0 {
                    Text(Self.thinking[clock.frame % Self.thinking.count]).foregroundStyle(AgentBrand.claudeOrange).fontWeight(.bold)
                }
                Text(Strings.sessionsCaption(working: store.workingCount)).foregroundStyle(.secondary)
                Spacer()
                settingsMenu
            }
            if !store.agentSessions.isEmpty {
                section(Strings.byProject)
                SessionsByProjectView(sessions: store.agentSessions, working: store.workingSessions)
            }
            Divider()
            section(Strings.versions)
            if versions.reports.isEmpty {
                Text(Strings.noAgent).foregroundStyle(.secondary).padding(.horizontal, 6)
            }
            ForEach(versions.reports) { report in
                AgentVersionRow(report: report, sessions: store.sessions(of: report.agent))
            }
        }
        .font(.system(size: 12.5))
        .padding(14)
        .frame(width: 360)
        .onAppear {
            store.setWindow(.agent(agent), isOpen: true)
            Task { await versions.refreshIfStale() }
        }
        .onDisappear { store.setWindow(.agent(agent), isOpen: false) }
    }

    /// Returns the small capitalised title of a section.
    /// @example section("Versions")
    private func section(_ title: String) -> some View {
        Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).kerning(0.6).foregroundStyle(.secondary).padding(.top, 2)
    }

    private var settingsMenu: some View {
        Menu {
            Toggle(Strings.checkVersions, isOn: $versions.checksLatest)
            Toggle(Strings.animateLogo, isOn: $clock.isEnabled)
            Divider()
            Button(Strings.quit) { NSApplication.shared.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
