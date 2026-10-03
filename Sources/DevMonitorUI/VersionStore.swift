import DevMonitorCore
import Foundation

/// The installed and latest versions of the agents, checked when the app starts and then every six hours.
@MainActor
public final class VersionStore: ObservableObject {
    @Published private(set) var reports: [AgentVersionReport] = []
    /// Whether the app asks the public registries for new versions; remembered, and on by default.
    @Published var checksLatest: Bool {
        didSet {
            UserDefaults.standard.set(checksLatest, forKey: Self.checksLatestKey)
            Task { await refresh() }
        }
    }

    private static let checksLatestKey = "checksLatestVersions"
    private static let period: TimeInterval = 6 * 3600
    private var loop: Task<Void, Never>?
    private var refreshedAt = Date.distantPast
    /// Counts the refreshes started: when several overlap, only the latest one publishes.
    private var refreshes = 0

    /// Creates the store and starts checking: now, then every six hours.
    /// @example VersionStore() // reading the installed versions
    public init() {
        checksLatest = UserDefaults.standard.object(forKey: Self.checksLatestKey) as? Bool ?? true
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(Self.period))
            }
        }
    }

    /// The agents installed on this Mac, in the order of `Agent.allCases`.
    var installedAgents: [Agent] { reports.map(\.agent) }

    /// Whether a newer version of this agent is published.
    /// @example store.isOutdated(.claude) // false
    func isOutdated(_ agent: Agent) -> Bool {
        reports.first { $0.agent == agent }?.isOutdated ?? false
    }

    /// Checks again when the last check is more than five minutes old, e.g. right after an update.
    /// @example await store.refreshIfStale()
    func refreshIfStale() async {
        if Date().timeIntervalSince(refreshedAt) > 300 { await refresh() }
    }

    /// Reads the installed versions and, when the check is on, the latest published ones. A refresh that a newer
    /// one overtook publishes nothing, so turning the check off is never undone by a slower check still running.
    /// @example await store.refresh()
    public func refresh() async {
        refreshes += 1
        let refresh = refreshes
        let checks = checksLatest
        refreshedAt = Date()
        let installed = await BlockingWork.run { InstalledAgents.versions() }
        let latest = checks ? await LatestVersions.fetch(installed.map(\.agent)) : [:]
        guard refresh == refreshes else { return }
        reports = installed.map { AgentVersionReport(agent: $0.agent, installed: $0.version, latest: latest[$0.agent]) }
    }
}
