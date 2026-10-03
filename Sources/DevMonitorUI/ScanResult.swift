import DevMonitorCore
import Foundation

/// The result of one scan, ready to display.
struct ScanResult: Sendable {
    let groups: [ProjectGroup]
    /// How many seconds each idle service has done nothing, by service id; absent for a service that is not idle.
    let idleSeconds: [String: Int]
    /// The coding agent sessions running, and the ids of those that worked since the previous scan.
    let agentSessions: [AgentSession]
    let workingSessions: Set<String>
    /// The identity of every process seen during the scan.
    let processIdentities: Set<String>
}
