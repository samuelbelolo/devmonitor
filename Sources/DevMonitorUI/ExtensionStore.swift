import Combine
import DevMonitorCore
import Foundation

/// The installed skills and plugins and their update states. The files are read again each time the agents window
/// opens; GitHub is asked about the skills when the app starts, then every six hours, and only while the version
/// check of `VersionStore` is on. Between two checks, a repository that was never asked is asked once.
@MainActor
public final class ExtensionStore: ObservableObject {
    @Published private(set) var report = ExtensionReport.empty
    /// When GitHub last answered about the skills; nil until it does and while the check is off.
    @Published private(set) var checkedAt: Date?

    private static let period: TimeInterval = 6 * 3600
    private let versions: VersionStore
    private let repoTrees = RepoTrees()
    /// The repository trees GitHub gave so far.
    private var latestTrees: [SkillSource: RepoTree] = [:]
    /// The repositories asked since the last full check, answered or not: a refused one is not asked at every opening.
    private var asked: Set<SkillSource> = []
    /// Counts the reports started: when several overlap, only the latest one is published.
    private var reports = 0
    private var loop: Task<Void, Never>?
    private var toggle: AnyCancellable?

    /// Creates the store and starts checking: now, then every six hours, and again when the version check is switched.
    /// @example ExtensionStore(versions: versions)
    public init(versions: VersionStore) {
        self.versions = versions
        toggle = versions.$checksLatest.dropFirst().sink { [weak self] _ in
            // The new value is set once this closure returns, so the refresh reads it from a later task.
            Task { await self?.refresh(fetchingUpstream: true) }
        }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh(fetchingUpstream: true)
                try? await Task.sleep(for: .seconds(Self.period))
            }
        }
    }

    /// Reads the installed skills and plugins, asks GitHub when the check is on (about every skill repository when
    /// `fetchingUpstream` is set, otherwise only about those never asked), then publishes the report.
    /// @example await store.refresh(fetchingUpstream: false)
    public func refresh(fetchingUpstream: Bool) async {
        let installed = await BlockingWork.run { InstalledExtensions.read() }
        if versions.checksLatest {
            await ask(installed.skillSources, all: fetchingUpstream)
        }
        if !versions.checksLatest {
            latestTrees = [:]
            asked = []
            checkedAt = nil
        }
        // Numbered after the answers are stored: a refresh that waited on GitHub is the latest one to report.
        reports += 1
        let number = reports
        let checks = versions.checksLatest
        let known = latestTrees
        let built = await BlockingWork.run { installed.report(trees: known, checksUpstream: checks, now: Date()) }
        guard number == reports else { return }
        report = built
    }

    /// Asks GitHub about the sources, or only those never asked, and keeps what it answers, whichever refresh
    /// reports first; an answer that arrives after the check was turned off is dropped.
    /// @example await ask(installed.skillSources, all: true)
    private func ask(_ sources: [SkillSource], all: Bool) async {
        let wanted = all ? sources : sources.filter { !asked.contains($0) }
        guard !wanted.isEmpty else { return }
        asked = all ? Set(sources) : asked.union(wanted)
        let fetched = await repoTrees.fetch(wanted)
        guard versions.checksLatest else { return }
        latestTrees.merge(fetched) { _, new in new }
        checkedAt = await repoTrees.lastAnswered
    }
}
