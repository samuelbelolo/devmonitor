import DevMonitorCore
import XCTest

final class BusiestAccountTests: XCTestCase {
    func testTheAccountMostSessionsDrawOnWins() {
        let key = BusiestAccount.key(among: ["a", "b", "c"], sessions: ["a": 1, "b": 4, "c": 2], percentUsed: ["a": 90, "b": 17, "c": 50], fallback: "a")
        XCTAssertEqual(key, "b")
    }

    func testATieGoesToTheFullestThenToTheFirstListed() {
        XCTAssertEqual(BusiestAccount.key(among: ["a", "b"], sessions: ["a": 2, "b": 2], percentUsed: ["a": 30, "b": 61], fallback: nil), "b")
        XCTAssertEqual(BusiestAccount.key(among: ["a", "b"], sessions: ["a": 2, "b": 2], percentUsed: ["b": 10], fallback: nil), "b")
        XCTAssertEqual(BusiestAccount.key(among: ["a", "b"], sessions: ["a": 2, "b": 2], percentUsed: [:], fallback: nil), "a")
    }

    func testSessionsOnAnAccountNotFollowedDoNotCount() {
        XCTAssertEqual(BusiestAccount.key(among: ["a", "b"], sessions: ["elsewhere": 9, "a": 1], percentUsed: [:], fallback: "b"), "a")
    }

    func testWithNoSessionTheAccountANewSessionWouldUseWins() {
        XCTAssertEqual(BusiestAccount.key(among: ["a", "b"], sessions: [:], percentUsed: ["a": 80], fallback: "b"), "b")
        XCTAssertEqual(BusiestAccount.key(among: ["a", "b"], sessions: ["elsewhere": 3], percentUsed: [:], fallback: "b"), "b")
    }

    func testNothingWinsWhenNoSessionRunsAndTheDefaultAccountIsNotFollowed() {
        XCTAssertNil(BusiestAccount.key(among: ["a", "b"], sessions: [:], percentUsed: ["a": 80], fallback: "elsewhere"))
        XCTAssertNil(BusiestAccount.key(among: ["a"], sessions: [:], percentUsed: [:], fallback: nil))
        XCTAssertNil(BusiestAccount.key(among: [], sessions: ["a": 2], percentUsed: [:], fallback: "a"))
    }
}
