import Foundation

/// A dev server, worker or tool: one root process and everything it spawned.
public struct Service: Identifiable, Equatable, Sendable {
    public let root: ProcessSnapshot
    /// The root, then the processes it owns, parents before children; never an app, an agent or an interactive shell.
    public let members: [ProcessSnapshot]
    public let label: String
    public let location: ProjectLocation
    /// The coding agent that started it, when one was among its ancestors.
    public let agent: Agent?
    /// An MCP server, or another tool an agent started for itself: stopping it breaks that agent's session.
    public let isMCP: Bool

    public init(root: ProcessSnapshot, members: [ProcessSnapshot], label: String, location: ProjectLocation, agent: Agent?, isMCP: Bool) {
        self.root = root
        self.members = members
        self.label = label
        self.location = location
        self.agent = agent
        self.isMCP = isMCP
    }

    public var id: String { root.identity }
    public var memoryBytes: UInt64 { members.reduce(0) { $0 + $1.memoryBytes } }
    public var cpuTimeNs: UInt64 { members.reduce(0) { $0 + $1.cpuTimeNs } }
    public var ports: [UInt16] { Array(Set(members.flatMap(\.ports))).sorted() }
    /// Its parent died and launchd adopted it.
    public var isOrphan: Bool { root.ppid == 1 }
}
