import XCTest
@testable import DevMonitorCore

final class IdleTrackerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)
    private let second: UInt64 = 1_000_000_000

    /// Builds a one-root service whose processes have used the given CPU time, in seconds.
    /// @example server(cpu: 3, worker: (51, 2)).members.count // 2
    private func server(cpu: UInt64, worker: (pid: Int32, cpu: UInt64)? = nil) -> Service {
        let root = snap(40, parent: 1, path: "/bin/pnpm", cpu: cpu * second)
        let workers = worker.map { [snap($0.pid, parent: 40, path: "/bin/node", cpu: $0.cpu * second)] } ?? []
        return service([root] + workers)
    }

    /// Records the same service every 30 s over a period and returns the last result.
    /// @example idle(after: 600) { _ in self.server(cpu: 1) } // 600
    private func idle(after seconds: Int, in tracker: inout IdleTracker, _ service: (Int) -> Service) -> Int? {
        var result: Int?
        for elapsed in stride(from: 0, through: seconds, by: 30) {
            result = tracker.record(service(elapsed), at: start + TimeInterval(elapsed))
        }
        return result
    }

    func testFirstSampleIsNotIdle() {
        var tracker = IdleTracker()
        XCTAssertNil(tracker.record(server(cpu: 1), at: start))
    }

    func testServiceWithoutCpuForTenMinutesIsIdle() {
        var tracker = IdleTracker()
        XCTAssertNil(idle(after: 570, in: &tracker) { _ in self.server(cpu: 1) })
        XCTAssertEqual(tracker.record(server(cpu: 1), at: start + 600), 600)
    }

    func testCpuUseResetsTheIdleClock() {
        var tracker = IdleTracker()
        XCTAssertNil(idle(after: 900, in: &tracker) { elapsed in self.server(cpu: elapsed < 600 ? 1 : UInt64(elapsed)) })
    }

    func testServiceThatKeepsReplacingItsWorkersIsNotIdle() {
        var tracker = IdleTracker()
        // Each worker has used less CPU than the one it replaces, so the total never grows.
        XCTAssertNil(idle(after: 900, in: &tracker) { elapsed in self.server(cpu: 1, worker: (Int32(100 + elapsed), 2)) })
    }

    func testTimeTheMacSpentAsleepIsNotIdleTime() {
        var tracker = IdleTracker()
        _ = tracker.record(server(cpu: 1), at: start)
        XCTAssertNil(tracker.record(server(cpu: 1), at: start + 8 * 3600))
        XCTAssertNil(tracker.record(server(cpu: 1), at: start + 8 * 3600 + 30))
    }

    func testForgottenServiceStartsOverAsNotIdle() {
        var tracker = IdleTracker()
        _ = idle(after: 600, in: &tracker) { _ in self.server(cpu: 1) }
        tracker.prune(keeping: [])
        XCTAssertNil(tracker.record(server(cpu: 1), at: start + 630))
    }
}
