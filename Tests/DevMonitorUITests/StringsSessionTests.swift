import XCTest
@testable import DevMonitorUI

final class StringsSessionTests: XCTestCase {
    func testSessionNamesItsAgentAndWhoLaunchedIt() {
        let launched = Strings.session(of: .codex, launchedBy: .claude)
        XCTAssertTrue(launched.hasPrefix("Codex, "))
        XCTAssertTrue(launched.hasSuffix(" Claude"))
        XCTAssertEqual(Strings.session(of: .codex, launchedBy: nil), "Codex")
    }
}
