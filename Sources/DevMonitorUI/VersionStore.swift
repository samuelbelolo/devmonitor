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
            guard !isSample else { return }
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
    /// Tells when an update replaces an agent's command, so its version is read then and not only when a window opens.
    private var watcher: FileWatcher?
    /// The commands the watcher follows.
    private var watched: [String] = []
    /// Whether the store shows fixed reports: it then reads no command of this Mac and asks no registry.
    private let isSample: Bool

    /// Creates the store and starts checking: now, then every six hours.
    /// @example VersionStore() // reading the installed versions
    public init() {
        isSample = false
        checksLatest = UserDefaults.standard.object(forKey: Self.checksLatestKey) as? Bool ?? true
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh(fetchingLatest: true)
                try? await Task.sleep(for: .seconds(Self.period))
            }
        }
    }

    /// Creates a store that shows these reports and never reads this Mac: the documentation's images come from it.
    /// @example VersionStore(sample: SampleData.versions).installedAgents // [.claude, .codex]
    init(sample: [AgentVersionReport]) {
        isSample = true
        checksLatest = true
        reports = sample
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
        guard !isSample else { return }
        refreshes += 1
        let refresh = refreshes
        let checks = checksLatest
        let installed = await BlockingWork.run { InstalledAgents.versions() }
        let commands = await BlockingWork.run { InstalledAgents.executables() }
        watch(commands.map(\.path))
        let found = checks && fetchingLatest ? await LatestVersions.fetch(commands) : latest
        guard refresh == refreshes else { return }
        latest = checks ? found : [:]
        reports = installed.map { AgentVersionReport(agent: $0.agent, installed: $0.version, latest: latest[$0.agent]) }
    }

    /// Follows the agents' commands: when an update replaces one, the installed versions are read again, so the
    /// menu bar and the window are right before anyone opens them. Does nothing while the commands are the same.
    /// @example watch(["/Users/me/.local/bin/claude"])
    private func watch(_ commands: [String]) {
        guard commands != watched else { return }
        watched = commands
        watcher = FileWatcher(files: commands) { [weak self] in
            Task { @MainActor in await self?.refreshInstalled() }
        }
    }
}
