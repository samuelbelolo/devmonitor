import XCTest
@testable import DevMonitorCore

final class DisplayTextTests: XCTestCase {
    func testLineBreaksBecomeSpaces() {
        XCTAssertEqual(DisplayText.clean("pnpm dev\nINJECTED"), "pnpm dev INJECTED")
    }

    func testControlAndDirectionCharactersAreRemoved() {
        XCTAssertEqual(DisplayText.clean("a\u{202E}b\u{1B}[31mc\u{200B}"), "ab[31mc")
    }

    func testLongTextIsCutWithAnEllipsis() {
        XCTAssertEqual(DisplayText.clean(String(repeating: "a", count: 100), limit: 10), "aaaaaaaaa…")
    }

    func testOrdinaryNamesAreLeftAlone() {
        XCTAssertEqual(DisplayText.clean("@scope/été-app (v2)"), "@scope/été-app (v2)")
    }
}
