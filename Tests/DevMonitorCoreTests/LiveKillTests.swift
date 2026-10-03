import XCTest
@testable import DevMonitorCore

/// Exercises the real scanner and the real signals on a process this test starts itself.
final class LiveKillTests: XCTestCase {
    func testScannedChildProcessIsTerminatedBySigterm() throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["300"]
        try child.run()
        defer { if child.isRunning { child.terminate() } }

        let tree = ProcessTree(ProcessScanner.scan())
        let scanned = try XCTUnwrap(tree.snapshot(pid: child.processIdentifier))
        XCTAssertEqual(scanned.ppid, getpid())
        XCTAssertEqual(scanned.name, "sleep")

        let outcomes = ProcessKiller().signal([scanned], with: SIGTERM)
        child.waitUntilExit()

        XCTAssertEqual(outcomes, [.signalled(child.processIdentifier)])
        XCTAssertEqual(child.terminationReason, .uncaughtSignal)
    }

    func testScanReportsTheWorkingDirectoryAndMemoryOfThisProcess() throws {
        let me = try XCTUnwrap(ProcessScanner.scan().first { $0.pid == getpid() })
        XCTAssertEqual(me.workingDirectory, FileManager.default.currentDirectoryPath)
        XCTAssertGreaterThan(me.memoryBytes, 1_000_000)
    }
}
