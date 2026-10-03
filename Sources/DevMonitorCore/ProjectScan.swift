import Foundation

/// One look at the machine: what runs, grouped by project. Shared by the app and by `devmon-dump`.
public struct ProjectScan: Sendable {
    public let groups: [ProjectGroup]
    /// The coding agent sessions running, in pid order.
    public let agentSessions: [AgentSession]
    /// The identity of every process seen, to tell which stop requests still have a target.
    public let processIdentities: Set<String>

    /// Builds the services of the given processes, attaches the containers to their project and groups everything.
    /// @example ProjectScan.run(containers: DockerCLI.containers(), resolver: RepoResolver()).groups.map(\.name) // ["shop", "MCP servers"]
    public static func run(
        processes: [ProcessSnapshot] = ProcessScanner.scan(), containers: [DockerContainer], resolver: RepoResolver,
        now: UInt64 = UInt64(Date().timeIntervalSince1970)
    ) -> ProjectScan {
        let tree = ProcessTree(processes)
        let services = ServiceBuilder(resolver: resolver).services(in: tree, now: now)
        let located = ContainerLocator.locate(containers, resolver: resolver)
        return ProjectScan(
            groups: ProjectGrouper.groups(services: services, containers: located),
            agentSessions: AgentSessionFinder.sessions(in: tree, resolver: resolver),
            processIdentities: Set(processes.map(\.identity)))
    }
}
