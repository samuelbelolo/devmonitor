import XCTest
@testable import DevMonitorCore

final class VersionNumberTests: XCTestCase {
    func testVersionIsReadFromWhatACommandPrints() {
        XCTAssertEqual(VersionNumber(parsing: "2.1.288 (Claude Code)")?.text, "2.1.288")
        XCTAssertEqual(VersionNumber(parsing: "codex-cli 0.160.0")?.text, "0.160.0")
        XCTAssertEqual(VersionNumber(parsing: "rust-v0.160.0")?.text, "0.160.0")
        XCTAssertNil(VersionNumber(parsing: "command not found"))
    }

    func testVersionsCompareNumberByNumber() {
        XCTAssertLessThan(VersionNumber(parsing: "2.1.9")!, VersionNumber(parsing: "2.1.10")!)
        XCTAssertLessThan(VersionNumber(parsing: "0.160.0")!, VersionNumber(parsing: "0.161")!)
        XCTAssertEqual(VersionNumber(parsing: "1.2")!, VersionNumber(parsing: "1.2.0")!)
    }
}
