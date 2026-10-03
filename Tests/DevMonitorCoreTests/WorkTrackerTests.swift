import XCTest
@testable import DevMonitorCore

final class WorkTrackerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)
    private let second: UInt64 = 1_000_000_000

    /// Builds a Claude session whose process has used the given CPU time, in seconds.
    /// @example session(cpu: 2).process.cpuTimeNs // 2_000_000_000
    private func session(cpu: Double) -> AgentSession {
        AgentSession(agent: .claude, process: snap(20, parent: 1, path: "/bin/claude", cpu: UInt64(cpu * 1e9)), location: nil)
    }

    func testSessionIsNotWorkingOnItsFirstSample() {
        var tracker = WorkTracker()
        XCTAssertEqual(tracker.record([session(cpu: 5)], at: start), [])
    }

    func testSessionThatUsedCpuSinceTheLastScanIsWorking() {
        var tracker = WorkTracker()
        _ = tracker.record([session(cpu: 5)], at: start)
        XCTAssertEqual(tracker.record([session(cpu: 6)], at: start + 10), ["20-100"])
    }

    func testSessionWaitingForItsUserIsNotWorking() {
        var tracker = WorkTracker()
        _ = tracker.record([session(cpu: 5)], at: start)
        XCTAssertEqual(tracker.record([session(cpu: 5.05)], at: start + 10), [])
    }

    func testSessionWhoseAgentChildWorksIsWorking() {
        var tracker = WorkTracker()
        let wrapper = snap(20, parent: 1, path: "/opt/homebrew/bin/node", cpu: 1_000_000_000)
        _ = tracker.record([AgentSession(agent: .codex, process: wrapper, location: nil, cpuTimeNs: 5_000_000_000)], at: start)
        let later = AgentSession(agent: .codex, process: wrapper, location: nil, cpuTimeNs: 6_000_000_000)
        XCTAssertEqual(tracker.record([later], at: start + 10), ["20-100"])
    }

    func testCpuUsedWhileTheMacSleptProvesNothing() {
        var tracker = WorkTracker()
        _ = tracker.record([session(cpu: 5)], at: start)
        XCTAssertEqual(tracker.record([session(cpu: 50)], at: start + 3600), [])
    }
}
