import DevMonitorCore
import SwiftUI

/// The window opened from the agents menu bar item: the sessions, where they run, and the agents' versions.
public struct AgentsContentView: View {
    @EnvironmentObject private var store: MonitorStore
    @EnvironmentObject private var versions: VersionStore
    @EnvironmentObject private var extensions: ExtensionStore
    @EnvironmentObject private var clock: GlyphClock

    /// The glyphs Claude Code itself cycles through while it thinks.
    private static let thinking = ["·", "✢", "✳", "✶", "✻", "✽", "✻", "✶", "✳", "✢"]

    public init() {}

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
                SectionTitle(title: Strings.byProject)
                SessionsByProjectView(sessions: store.agentSessions, working: store.workingSessions)
            }
            Divider()
            SectionTitle(title: Strings.versions)
            if versions.reports.isEmpty {
                Text(Strings.noAgent).foregroundStyle(.secondary).padding(.horizontal, 6)
            }
            ForEach(versions.reports) { report in
                AgentVersionRow(report: report, sessions: store.sessions(of: report.agent))
            }
            ExtensionsSection()
        }
        .font(.system(size: 12.5))
        .padding(14)
        .frame(width: 360)
        .background(WindowFit())
        .onAppear {
            store.setWindow(.agents, isOpen: true)
            Task { await versions.refreshInstalled() }
            Task { await extensions.refresh(fetchingUpstream: false) }
        }
        .onDisappear { store.setWindow(.agents, isOpen: false) }
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
