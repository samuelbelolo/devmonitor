import Darwin
@testable import DevMonitorCore
import XCTest

final class ProcessEnvironmentTests: XCTestCase {
    /// Returns a KERN_PROCARGS2 block: argc, the executable path and its padding, the arguments, then the environment.
    /// @example block(arguments: ["a"], environment: ["X=1"]).count // 22
    private func block(arguments: [String], environment: [String]) -> [UInt8] {
        var bytes = withUnsafeBytes(of: Int32(arguments.count)) { Array($0) }
        bytes += Array("/usr/bin/tool".utf8) + [0, 0, 0]
        for text in arguments + environment { bytes += Array(text.utf8) + [0] }
        return bytes + [0, 0]
    }

    func testReadsTheNamedVariablesThatFollowTheArguments() {
        let bytes = block(arguments: ["tool", "X=not-a-variable"], environment: ["HOME=/Users/me", "X=1", "OTHER=2"])
        XCTAssertEqual(ProcessEnvironment.values(["HOME", "X"], in: bytes), ["HOME": "/Users/me", "X": "1"])
    }

    func testAVariableSetEmptyIsKeptAndOneNotSetIsAbsent() {
        let bytes = block(arguments: ["tool"], environment: ["ANTHROPIC_API_KEY=", "HOME=/h"])
        XCTAssertEqual(ProcessEnvironment.values(["ANTHROPIC_API_KEY", "CLAUDE_CONFIG_DIR"], in: bytes), ["ANTHROPIC_API_KEY": ""])
    }

    func testAValueMayHoldAnEqualsSign() {
        let bytes = block(arguments: ["tool"], environment: ["OPTS=a=b"])
        XCTAssertEqual(ProcessEnvironment.values(["OPTS"], in: bytes), ["OPTS": "a=b"])
    }

    func testABlockShorterThanItsArgumentCountIsUnreadable() {
        var bytes = withUnsafeBytes(of: Int32(5)) { Array($0) }
        bytes += Array("/usr/bin/tool".utf8) + [0] + Array("tool".utf8) + [0]
        XCTAssertNil(ProcessEnvironment.values(["HOME"], in: bytes))
    }

    func testReadsTheHomeThisTestStartedWith() {
        let home = ProcessInfo.processInfo.environment["HOME"]
        XCTAssertNotNil(home)
        XCTAssertEqual(ProcessEnvironment.values(["HOME"], of: getpid())?["HOME"], home)
    }
}
