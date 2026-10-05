import DevMonitorCore
import DevMonitorUI
import SwiftUI

@main
struct DevMonitorApp: App {
    @StateObject private var store = MonitorStore()
    @StateObject private var versions: VersionStore
    @StateObject private var extensions: ExtensionStore

    /// Refuses to run as root: the monitor only ever lists and signals the user's own processes.
    /// @example DevMonitorApp() // exits with status 1 under sudo
    init() {
        if getuid() == 0 {
            FileHandle.standardError.write(Data("DevMonitor does not run as root.\n".utf8))
            exit(1)
        }
        let versions = VersionStore()
        _versions = StateObject(wrappedValue: versions)
        _extensions = StateObject(wrappedValue: ExtensionStore(versions: versions))
    }

    // Items created later sit further left in the menu bar: memory first, then the agents.
    var body: some Scene {
        MenuBarExtra {
            MenuContentView().environmentObject(store)
        } label: {
            Image(systemName: "memorychip")
            Text(DisplayFormat.memory(store.totalBytes))
        }
        .menuBarExtraStyle(.window)
        MenuBarExtra {
            AgentsContentView().agentEnvironment(store: store, versions: versions, extensions: extensions)
        } label: {
            AgentMenuBarLabel().agentEnvironment(store: store, versions: versions, extensions: extensions)
        }
        .menuBarExtraStyle(.window)
    }
}
