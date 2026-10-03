import DevMonitorCore
import DevMonitorUI
import SwiftUI

@main
struct DevMonitorApp: App {
    @StateObject private var store = MonitorStore()
    @StateObject private var versions = VersionStore()

    /// Refuses to run as root: the monitor only ever lists and signals the user's own processes.
    /// @example DevMonitorApp() // exits with status 1 under sudo
    init() {
        if getuid() == 0 {
            FileHandle.standardError.write(Data("DevMonitor does not run as root.\n".utf8))
            exit(1)
        }
    }

    // Items created later sit further left in the menu bar: memory first, then one item per agent, one per
    // `Agent` case (a scene builder cannot loop over `Agent.allCases`).
    var body: some Scene {
        MenuBarExtra {
            MenuContentView().environmentObject(store)
        } label: {
            Image(systemName: "memorychip")
            Text(DisplayFormat.memory(store.totalBytes))
        }
        .menuBarExtraStyle(.window)
        agentItem(.claude)
        agentItem(.codex)
        agentItem(.gemini)
        agentItem(.cursorAgent)
        agentItem(.opencode)
        agentItem(.aider)
        agentItem(.amp)
    }

    /// Returns the menu bar item of one agent, shown only while `AgentMenuBarItems` says so.
    /// @example agentItem(.codex)
    private func agentItem(_ agent: Agent) -> some Scene {
        let isShown = Binding(get: { AgentMenuBarItems.isShown(agent, store: store, versions: versions) }, set: { _ in })
        return MenuBarExtra(isInserted: isShown) {
            AgentsContentView(agent: agent).agentEnvironment(store: store, versions: versions)
        } label: {
            AgentMenuBarLabel(agent: agent).agentEnvironment(store: store, versions: versions)
        }
        .menuBarExtraStyle(.window)
    }
}
