import XCTest
@testable import DevMonitorCore

final class SwapUsageTests: XCTestCase {
    private let gigabyte: UInt64 = 1_073_741_824

    /// Returns the state of a Mac with 48 GB of memory and `used` bytes of swap in use.
    /// @example state(used: 30 * gigabyte) // .critical
    private func state(used: UInt64) -> SwapState {
        SwapUsage(usedBytes: used, installedBytes: 48 * gigabyte).state
    }

    func testSwapIsFineUpToAQuarterOfTheInstalledMemory() {
        XCTAssertEqual(state(used: 0), .fine)
        XCTAssertEqual(state(used: 12 * gigabyte), .fine)
    }

    func testSwapIsHighAboveAQuarterOfTheInstalledMemory() {
        XCTAssertEqual(state(used: 12 * gigabyte + 1), .high)
        XCTAssertEqual(state(used: 24 * gigabyte), .high)
    }

    func testSwapIsCriticalAboveHalfOfTheInstalledMemory() {
        XCTAssertEqual(state(used: 24 * gigabyte + 1), .critical)
        // What this Mac held on 14 November 2026, after eleven days without a restart.
        XCTAssertEqual(state(used: 30_523 * 1_048_576), .critical)
    }

    func testTheThresholdsFollowTheMemoryOfTheMac() {
        XCTAssertEqual(SwapUsage(usedBytes: 5 * gigabyte, installedBytes: 16 * gigabyte).state, .high)
        XCTAssertEqual(SwapUsage(usedBytes: 9 * gigabyte, installedBytes: 16 * gigabyte).state, .critical)
        XCTAssertEqual(SwapUsage(usedBytes: 9 * gigabyte, installedBytes: 0).state, .fine)
    }

    func testThisMacAnswersWithItsSwapAndItsMemory() throws {
        let usage = try XCTUnwrap(SwapUsage.read())
        XCTAssertEqual(usage.installedBytes, ProcessInfo.processInfo.physicalMemory)
    }

    func testThisMacSaysWhenItStarted() throws {
        let started = try XCTUnwrap(BootTime.read())
        XCTAssertLessThan(started, Date())
        XCTAssertGreaterThan(started, Date(timeIntervalSince1970: 1_600_000_000))
    }
}
