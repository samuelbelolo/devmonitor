import Foundation

/// One running session of a coding agent.
public struct AgentSession: Identifiable, Equatable, Sendable {
    public let agent: Agent
    /// The agent's own process, the top one when a wrapper starts it.
    public let process: ProcessSnapshot
    /// The project the session was started in; nil outside any project.
    public let location: ProjectLocation?
    /// CPU time of the session: its process and the processes of the same agent below it, such as the native
    /// binary an npm launcher starts and waits for.
    public let cpuTimeNs: UInt64

    /// Creates a session; its CPU time defaults to its process's own.
    /// @example AgentSession(agent: .claude, process: claudeProcess, location: nil).cpuTimeNs // claudeProcess.cpuTimeNs
    public init(agent: Agent, process: ProcessSnapshot, location: ProjectLocation?, cpuTimeNs: UInt64? = nil) {
        self.agent = agent
        self.process = process
        self.location = location
        self.cpuTimeNs = cpuTimeNs ?? process.cpuTimeNs
    }

    public var id: String { process.identity }
    /// The version the session runs, read from its executable's path; nil when an interpreter runs it, since the
    /// interpreter's path carries its own version (`/Cellar/node/24.1.0/bin/node`).
    public var version: VersionNumber? { Agent.interprets(process) ? nil : VersionNumber(parsing: process.executablePath) }
}
