import SwiftUI

extension View {
    /// Gives an agent view the stores it reads: the scan, the versions and the logo's clock.
    /// @example AgentsContentView(agent: .claude).agentEnvironment(store: store, versions: versions)
    public func agentEnvironment(store: MonitorStore, versions: VersionStore) -> some View {
        environmentObject(store).environmentObject(versions).environmentObject(store.clock)
    }
}
