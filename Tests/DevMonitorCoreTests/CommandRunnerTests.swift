import XCTest
@testable import DevMonitorCore

final class CommandRunnerTests: XCTestCase {
    func testOutputOfACommandIsReturned() {
        XCTAssertEqual(CommandRunner.run("/bin/echo", ["hello"], timeout: 5), "hello\n")
    }

    func testFailingCommandReturnsNil() {
        XCTAssertNil(CommandRunner.run("/bin/sh", ["-c", "exit 3"], timeout: 5))
    }

    func testCommandStillRunningAtTheDeadlineReturnsNil() {
        let start = Date()
        XCTAssertNil(CommandRunner.run("/bin/sleep", ["5"], timeout: 0.5))
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }

    func testChildKeepingTheOutputOpenDoesNotHoldTheResult() {
        let start = Date()
        XCTAssertEqual(CommandRunner.run("/bin/sh", ["-c", "sleep 8 & echo hi"], timeout: 5), "hi\n")
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }

    func testEnvironmentIsPassedToTheCommand() {
        XCTAssertEqual(CommandRunner.run("/bin/sh", ["-c", "echo $DEVMON_PROBE"], timeout: 5, environment: ["DEVMON_PROBE": "yes"]), "yes\n")
    }
}
