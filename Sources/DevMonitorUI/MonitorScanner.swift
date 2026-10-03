import DevMonitorCore
import Foundation

/// Runs scans off the main thread and keeps the state that spans scans.
actor MonitorScanner {
    private let resolver = RepoResolver()
    private var tracker = IdleTracker()
    private var workTracker = WorkTracker()
    private var cacheClearedAt = Date()
    /// Seconds a resolved directory is trusted before it is looked up again.
    private static let cacheLifetime: TimeInterval = 300

    /// Scans the processes, attaches the given containers to their project and returns the groups.
    /// @example await scanner.scan(containers: []).groups.map(\.name) // ["shop", "MCP servers"]
    func scan(containers: [DockerContainer]) -> ScanResult {
        let now = Date()
        if now.timeIntervalSince(cacheClearedAt) > Self.cacheLifetime {
            resolver.clearCache()
            cacheClearedAt = now
        }
        let scan = ProjectScan.run(containers: containers, resolver: resolver)
        let services = scan.groups.flatMap(\.services)
        var idleSeconds: [String: Int] = [:]
        for service in services {
            idleSeconds[service.id] = tracker.record(service, at: now)
        }
        tracker.prune(keeping: Set(services.map(\.id)))
        return ScanResult(
            groups: scan.groups, idleSeconds: idleSeconds, agentSessions: scan.agentSessions,
            workingSessions: workTracker.record(scan.agentSessions, at: now), processIdentities: scan.processIdentities)
    }
}
