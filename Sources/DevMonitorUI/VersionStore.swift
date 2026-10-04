import DevMonitorCore
import Foundation

/// The installed and latest versions of the agents. The installed ones are read again each time an agent window
/// opens, since an update can happen at any time; the registries are asked when the app starts, then every six hours.
@MainActor
public final class VersionStore: ObservableObject {
    @Published private(set) var reports: [AgentVersionReport] = []
    /// Whether the app asks the public registries for new versions; remembered, and on by default.
    @Published var checksLatest: Bool {
        didSet {
            UserDefaults.standard.set(checksLatest, forKey: Self.checksLatestKey)
            Task { await refresh(fetchingLatest: true) }
        }
    }

    private static let checksLatestKey = "checksLatestVersions"
    private static let period: TimeInterval = 6 * 3600
    private var loop: Task<Void, Never>?
    /// The latest published versions from the last registry check.
    private var latest: [Agent: VersionNumber] = [:]
    /// Counts the refreshes started: when several overlap, only the latest one publishes.
    private var refreshes = 0

    /// Creates the store and starts checking: now, then every six hours.
    /// @example VersionStore() // reading the installed versions
    public init() {
        checksLatest = UserDefaults.standard.object(forKey: Self.checksLatestKey) as? Bool ?? true
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh(fetchingLatest: true)
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

    /// Reads the installed versions again, e.g. right after an update; the registries are not asked.
    /// @example await store.refreshInstalled()
    func refreshInstalled() async {
        await refresh(fetchingLatest: false)
    }

    /// Reads the installed versions and, when `fetchingLatest` is set and the check is on, asks the registries
    /// for the latest ones; otherwise the last answer is kept. A refresh that a newer one overtook publishes
    /// nothing, so turning the check off is never undone by a slower check still running.
    /// @example await store.refresh(fetchingLatest: true)
    public func refresh(fetchingLatest: Bool) async {
        refreshes += 1
        let refresh = refreshes
        let checks = checksLatest
        let installed = await BlockingWork.run { InstalledAgents.versions() }
        let found = checks && fetchingLatest ? await LatestVersions.fetch(installed.map(\.agent)) : latest
        guard refresh == refreshes else { return }
        latest = checks ? found : [:]
        reports = installed.map { AgentVersionReport(agent: $0.agent, installed: $0.version, latest: latest[$0.agent]) }
    }
}
