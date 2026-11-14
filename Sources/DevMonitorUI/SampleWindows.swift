import DevMonitorCore
import SwiftUI

/// The app's windows and menu bar items filled with a made-up Mac, for the images of the documentation. Their stores
/// never scan, never ask the network and stop nothing.
@MainActor
public enum SampleWindows {
    /// Returns the memory window of the sample Mac, its swap in the given state.
    /// @example SampleWindows.memory(swap: .critical) // the window with a red Swap line and the call to restart
    public static func memory(swap: SwapState = .fine) -> some View {
        MenuContentView().environmentObject(store(swap: swap))
    }

    /// Returns the agents window of the sample Mac: nine sessions, a Claude to update, skills and plugins to update.
    /// @example SampleWindows.agents() // the window with "2.1.291 available"
    public static func agents() -> some View {
        withAgentStores(AgentsContentView(), swap: .fine)
    }

    /// Returns the Swap line of the memory window in its three states, one under the other.
    /// @example SampleWindows.swapLines() // grey, orange, then red with the call to restart
    public static func swapLines() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach([SwapState.fine, .high, .critical], id: \.self) { state in
                SwapLineView(swap: SampleData.swap(state), startedAt: startedAt)
            }
        }
        .font(.system(size: 12.5))
        .padding(14)
        .frame(width: 400)
    }

    /// Returns the two menu bar items side by side, as they sit in the menu bar, the swap in the given state.
    /// @example SampleWindows.menuBar(swap: .high) // the agents item, then an orange chip and "19.0 GB"
    public static func menuBar(swap: SwapState = .fine) -> some View {
        let items = HStack(spacing: 18) {
            HStack(spacing: 5) { AgentMenuBarLabel() }
            HStack(spacing: 5) { MemoryMenuBarLabel() }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        return withAgentStores(items, swap: swap)
    }

    /// The sample Mac started eleven days ago.
    private static var startedAt: Date { Date().addingTimeInterval(-11 * 86_400) }

    /// Returns a store that shows the sample scan.
    /// @example store(swap: .fine).totalBytes // 19.0 GB
    private static func store(swap: SwapState) -> MonitorStore {
        MonitorStore(sample: SampleData.scan(swap: swap), startedAt: startedAt)
    }

    /// Gives a view the three sample stores an agent view reads, the extensions checked three minutes ago.
    /// @example withAgentStores(AgentsContentView(), swap: .fine)
    private static func withAgentStores(_ view: some View, swap: SwapState) -> some View {
        let versions = VersionStore(sample: SampleData.versions)
        let extensions = ExtensionStore(sample: SampleData.extensions, checkedAt: Date().addingTimeInterval(-180), versions: versions)
        return view.agentEnvironment(store: store(swap: swap), versions: versions, extensions: extensions)
    }
}
