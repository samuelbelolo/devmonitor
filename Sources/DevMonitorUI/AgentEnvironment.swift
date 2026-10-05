import SwiftUI

extension View {
    /// Gives an agent view the stores it reads: the scan, the versions, the extensions and the logo's clock.
    /// @example AgentsContentView().agentEnvironment(store: store, versions: versions, extensions: extensions)
    public func agentEnvironment(store: MonitorStore, versions: VersionStore, extensions: ExtensionStore) -> some View {
        environmentObject(store).environmentObject(versions).environmentObject(extensions).environmentObject(store.clock)
    }
}
