import XCTest
@testable import DevMonitorCore

final class ProcessKillerTests: XCTestCase {
    private var signalled: [Int32] = []

    /// Builds a killer that sees the given processes as the running ones and records the pids it signals.
    /// @example killer(running: [node]).signal([node], with: SIGTERM) // [.signalled(50)]
    private func killer(running: [ProcessSnapshot]) -> ProcessKiller {
        ProcessKiller(
            inspect: { pid in running.first { $0.pid == pid } },
            send: { [unowned self] pid, _ in self.signalled.append(pid); return 0 })
    }

    func testSignalIsSentToEveryTargetInTheOrderGiven() {
        let targets = [snap(40, parent: 1, path: "/bin/pnpm"), snap(50, parent: 40, path: "/bin/node")]
        XCTAssertEqual(killer(running: targets).signal(targets, with: SIGTERM), [.signalled(40), .signalled(50)])
        XCTAssertEqual(signalled, [40, 50])
    }

    func testProcessThatEndedIsNotSignalled() {
        XCTAssertEqual(killer(running: []).signal([snap(50, parent: 1, path: "/bin/node")], with: SIGTERM), [.gone(50)])
        XCTAssertTrue(signalled.isEmpty)
    }

    func testRecycledPidIsNotSignalled() {
        let scanned = snap(50, parent: 1, path: "/bin/node", start: 100)
        let recycled = snap(50, parent: 1, path: "/bin/node", start: 999)
        XCTAssertEqual(killer(running: [recycled]).signal([scanned], with: SIGTERM), [.gone(50)])
        XCTAssertTrue(signalled.isEmpty)
    }

    func testProtectedProcessIsRefusedEvenWhenPassedDirectly() {
        let targets = [agentChain()[0], agentChain()[1], terminalChain()[1]]
        XCTAssertEqual(killer(running: targets).signal(targets, with: SIGTERM), [.refused(10), .refused(20), .refused(90)])
        XCTAssertTrue(signalled.isEmpty)
    }

    func testProcessThatBecameAnAgentSinceTheScanIsRefused() {
        let scanned = snap(50, parent: 1, path: "/bin/sh", args: ["sh", "-c", "exec claude"])
        let now = snap(50, parent: 1, path: "/Users/me/.local/bin/claude", args: ["claude"])
        XCTAssertEqual(killer(running: [now]).signal([scanned], with: SIGKILL), [.refused(50)])
        XCTAssertTrue(signalled.isEmpty)
    }

    func testProcessThatBecameAnotherProgramSinceTheScanIsNotSignalled() {
        let scanned = snap(50, parent: 1, path: "/bin/sh", args: ["sh", "-c", "exec node server.js"])
        let now = snap(50, parent: 1, path: "/opt/homebrew/bin/node", args: ["node", "server.js"])
        XCTAssertEqual(killer(running: [now]).signal([scanned], with: SIGTERM), [.gone(50)])
        XCTAssertTrue(signalled.isEmpty)
    }

    func testTheMonitorNeverSignalsItselfOrLaunchd() {
        let targets = [snap(getpid(), parent: 1, path: "/bin/node"), snap(1, parent: 0, path: "/bin/node")]
        XCTAssertEqual(killer(running: targets).signal(targets, with: SIGTERM), [.refused(getpid()), .refused(1)])
        XCTAssertTrue(signalled.isEmpty)
    }
}
