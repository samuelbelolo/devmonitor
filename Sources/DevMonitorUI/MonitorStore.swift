import DevMonitorCore
import Foundation

/// The state the menu bar items and their windows show, refreshed on a timer: the projects and their memory,
/// and the coding agent sessions.
@MainActor
public final class MonitorStore: ObservableObject {
    @Published private(set) var groups: [ProjectGroup] = []
    /// How many seconds each idle service has done nothing, by service id.
    @Published private(set) var idleSeconds: [String: Int] = [:]
    /// The coding agent sessions running, and the ids of those that worked during the last scan interval.
    @Published private(set) var agentSessions: [AgentSession] = []
    @Published private(set) var workingSessions: Set<String> = []
    /// When each process was asked to stop; 5 s later, a row whose processes are still alive offers to force them.
    @Published private(set) var stopRequests = StopRequests()
    /// The windows open right now; while one is, the refresh loops run at their faster pace.
    private var openWindows: Set<AppWindow> = [] { didSet { if openWindows.isEmpty != oldValue.isEmpty { startLoops() } } }
    private var isWindowVisible: Bool { !openWindows.isEmpty }

    /// Turns the logo of the working agents; it ticks only while a session works.
    public let clock = GlyphClock()
    private let scanner = MonitorScanner()
    private var containers: [DockerContainer] = []
    /// Containers a stop was requested for: hidden until Docker has answered.
    private var stoppingContainers: Set<String> = []
    private var containerReads = 0
    private var loop: Task<Void, Never>?
    private var dockerLoop: Task<Void, Never>?

    /// Creates the store and starts its two refresh loops: the processes, and the Docker containers.
    /// @example MonitorStore() // scanning every 30 s until the window opens
    public init() {
        startLoops()
    }

    public var totalBytes: UInt64 { groups.reduce(0) { $0 + $1.memoryBytes } }

    /// Records that one of the app's windows opened or closed.
    /// @example store.setWindow(.agent(.claude), isOpen: true)
    public func setWindow(_ window: AppWindow, isOpen: Bool) {
        if isOpen { openWindows.insert(window) } else { openWindows.remove(window) }
    }

    /// How many agent sessions worked during the last scan interval.
    var workingCount: Int { workingSessions.count }

    /// The sessions of one agent.
    /// @example store.sessions(of: .claude).count // 8
    public func sessions(of agent: Agent) -> [AgentSession] {
        agentSessions.filter { $0.agent == agent }
    }

    /// Whether a session of this agent worked during the last scan interval.
    /// @example store.isWorking(.claude) // true
    public func isWorking(_ agent: Agent) -> Bool {
        sessions(of: agent).contains { workingSessions.contains($0.id) }
    }

    /// The project services that have used no CPU for ten minutes. MCP servers and agent tools are never part of it.
    var idleServices: [Service] {
        groups.filter { $0.kind == .project }.flatMap(\.services).filter { idleSeconds[$0.id] != nil }
    }

    /// Whether a stop was requested for a service that is still running.
    /// @example store.isStopping(service) // true
    func isStopping(_ service: Service) -> Bool {
        stopRequests.date(for: service) != nil
    }

    /// Whether a stop was requested more than five seconds ago for a service that is still running.
    /// @example store.canForce(service) // true
    func canForce(_ service: Service) -> Bool {
        stopRequests.date(for: service).map { Date().timeIntervalSince($0) > 5 } ?? false
    }

    /// Rescans now and publishes the result.
    /// @example await store.refresh()
    public func refresh() async {
        let result = await scanner.scan(containers: containers.filter { !stoppingContainers.contains($0.id) })
        groups = result.groups
        idleSeconds = result.idleSeconds
        agentSessions = result.agentSessions
        workingSessions = result.workingSessions
        clock.update(hasWork: !workingSessions.isEmpty)
        stopRequests.prune(keeping: result.processIdentities)
    }

    /// Asks services to stop (SIGTERM), or kills them (SIGKILL) when `force` is set; each process is signalled
    /// on its own, the root of a service first.
    /// @example store.stop(group.services)
    func stop(_ services: [Service], force: Bool = false) {
        for service in services {
            _ = ProcessKiller().signal(service.members, with: force ? SIGKILL : SIGTERM)
        }
        stopRequests.record(services, at: Date())
        wake(after: 1)
    }

    /// Stops everything a project runs: its services and its Compose containers.
    /// @example store.stop(group)
    func stop(_ group: ProjectGroup) {
        stop(group.services)
        stop(containers: group.containers)
    }

    /// Stops Compose containers; they leave the list at once and come back if Docker did not stop them.
    /// @example store.stop(containers: group.containers)
    func stop(containers stopped: [DockerContainer]) {
        let ids = stopped.map(\.id)
        guard !ids.isEmpty else { return }
        stoppingContainers.formUnion(ids)
        Task {
            _ = await BlockingWork.run { DockerCLI.stop(ids) }
            await refreshContainers()
            stoppingContainers.subtract(ids)
            await refresh()
        }
        wake()
    }

    /// Reads the Compose containers again; when several reads overlap, only the latest one started is kept.
    /// @example await store.refreshContainers()
    private func refreshContainers() async {
        containerReads += 1
        let read = containerReads
        let found = await BlockingWork.run { DockerCLI.containers() }
        if read == containerReads { containers = found }
    }

    /// Restarts both refresh loops at the pace of the window: 3 s and 15 s when it is open, 30 s and 60 s otherwise.
    /// @example startLoops()
    private func startLoops() {
        loop?.cancel()
        dockerLoop?.cancel()
        loop = Self.every(isWindowVisible ? 3 : 30) { [weak self] in
            guard let self else { return false }
            await self.refresh()
            return true
        }
        dockerLoop = Self.every(isWindowVisible ? 15 : 60) { [weak self] in
            guard let self else { return false }
            await self.refreshContainers()
            return true
        }
    }

    /// Runs `work` now and then every `seconds`, until the task is cancelled or `work` answers false.
    /// @example every(3) { await refresh(); return true }
    private static func every(_ seconds: Double, _ work: @escaping @MainActor () async -> Bool) -> Task<Void, Never> {
        Task {
            while !Task.isCancelled, await work() {
                try? await Task.sleep(for: .seconds(seconds))
            }
        }
    }

    /// Triggers a refresh outside the timer, optionally after a delay in seconds.
    /// @example store.wake(after: 1)
    private func wake(after delay: Double = 0) {
        Task {
            try? await Task.sleep(for: .seconds(delay))
            await refresh()
        }
    }
}
