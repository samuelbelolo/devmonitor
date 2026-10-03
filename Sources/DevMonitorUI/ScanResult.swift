import DevMonitorCore
import Foundation

/// The result of one scan, ready to display.
struct ScanResult: Sendable {
    let groups: [ProjectGroup]
    /// How many seconds each idle service has done nothing, by service id; absent for a service that is not idle.
    let idleSeconds: [String: Int]
    /// The identity of every process seen during the scan.
    let processIdentities: Set<String>
}
