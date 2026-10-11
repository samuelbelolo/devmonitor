import Combine
import DevMonitorCore
import Foundation

/// The installed skills and plugins and their update states. The files are read again as soon as a tool changes
/// them, and each time the agents window opens. GitHub is asked about the skills when the app starts, then every
/// fifteen minutes, when the window opens after five minutes without a check, and on demand, only while the version
/// check of `VersionStore` is on; each check costs the API only for the repositories whose commit moved.
@MainActor
public final class ExtensionStore: ObservableObject {
    @Published private(set) var report = ExtensionReport.empty
    /// When GitHub last answered about the skills; nil until it does and while the check is off.
    @Published private(set) var checkedAt: Date?
    /// Whether GitHub is being asked about the skills right now.
    @Published private(set) var isChecking = false

    private static let period: TimeInterval = 15 * 60
    /// How old the last check may be when the window opens before GitHub is asked again.
    private static let freshness: TimeInterval = 5 * 60
    private let versions: VersionStore
    private let repoTrees = RepoTrees()
    /// The repository trees GitHub gave so far.
    private var latestTrees: [SkillSource: RepoTree] = [:]
    /// The repositories asked since the last full check, answered or not: a refused one is not asked at every opening.
    private var asked: Set<SkillSource> = []
    /// Counts the reports started: when several overlap, only the latest one is published.
    private var reports = 0
    /// How many checks of GitHub are running.
    private var checks = 0
    private var loop: Task<Void, Never>?
    private var toggle: AnyCancellable?
    private var watcher: FileWatcher?

    /// Creates the store and starts checking: now, then every fifteen minutes, again when the version check is
    /// switched, and on every change of the skills and plugins files.
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
        let home = NSHomeDirectory()
        watcher = FileWatcher(files: InstalledExtensions.watchedFiles.map { home + "/" + $0 }) { [weak self] in
            Task { @MainActor in await self?.refresh(fetchingUpstream: false) }
        }
    }

    /// Reads the files again when the window opens, and asks GitHub too when its last answer is old.
    /// @example await store.windowOpened()
    func windowOpened() async {
        let isStale = checkedAt.map { Date().timeIntervalSince($0) > Self.freshness } ?? true
        await refresh(fetchingUpstream: isStale)
    }

    /// Reads the installed skills and plugins, asks GitHub when the check is on (about every skill repository when
    /// `fetchingUpstream` is set, otherwise only about those never asked), then publishes the report.
    /// @example await store.refresh(fetchingUpstream: false)
    public func refresh(fetchingUpstream: Bool) async {
        let installed = await readInstalled()
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

    /// Reads the files; a skills lock caught while a tool rewrites it is read again a moment later, up to three times.
    /// @example await readInstalled().skills.count // 124
    private func readInstalled() async -> InstalledExtensions {
        var installed = await BlockingWork.run { InstalledExtensions.read() }
        for _ in 0..<3 where !installed.isSkillLockReadable {
            try? await Task.sleep(for: .milliseconds(400))
            installed = await BlockingWork.run { InstalledExtensions.read() }
        }
        return installed
    }

    /// Asks GitHub about the sources, or only those never asked, and keeps what it answers, whichever refresh
    /// reports first; an answer that arrives after the check was turned off is dropped.
    /// @example await ask(installed.skillSources, all: true)
    private func ask(_ sources: [SkillSource], all: Bool) async {
        let wanted = all ? sources : sources.filter { !asked.contains($0) }
        guard !wanted.isEmpty else { return }
        asked = all ? Set(sources) : asked.union(wanted)
        checks += 1
        isChecking = true
        let fetched = await repoTrees.fetch(wanted)
        checks -= 1
        isChecking = checks > 0
        guard versions.checksLatest else { return }
        latestTrees.merge(fetched) { _, new in new }
        checkedAt = await repoTrees.lastAnswered
    }
}
