import DevMonitorCore
import XCTest

final class AccountFreeAgainTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    /// Returns a reading whose limits have these shares used and resets, in seconds from `now`.
    /// @example usage([(100, 600)]).limits.count // 1
    private func usage(_ limits: [(Double, TimeInterval?)]) -> AccountUsage {
        AccountUsage(limits: limits.enumerated().map { AccountLimit(kind: .other("\($0.offset)"), percentUsed: $0.element.0, resetsAt: $0.element.1.map(now.addingTimeInterval)) })
    }

    func testAFullAccountComesBackWhenItsFullLimitResets() {
        XCTAssertEqual(AccountFreeAgain.date(of: usage([(100, 600), (40, 60)]), after: now), now.addingTimeInterval(600))
    }

    func testAnAccountComesBackOnlyOnceAllItsFullLimitsHaveReset() {
        XCTAssertEqual(AccountFreeAgain.date(of: usage([(97, 600), (95, 7200)]), after: now), now.addingTimeInterval(7200))
    }

    func testNothingShowsWhileTheAccountIsBelowTheCapOrUnread() {
        XCTAssertNil(AccountFreeAgain.date(of: usage([(94.9, 60)]), after: now))
        XCTAssertNil(AccountFreeAgain.date(of: nil, after: now))
    }

    func testAFullLimitWithoutAResetDateShowsNothing() {
        XCTAssertNil(AccountFreeAgain.date(of: usage([(96, nil)]), after: now))
        XCTAssertNil(AccountFreeAgain.date(of: usage([(96, nil), (97, 900)]), after: now))
    }

    func testAResetAlreadyPastShowsNothing() {
        XCTAssertNil(AccountFreeAgain.date(of: usage([(96, 600)]), after: now.addingTimeInterval(600)))
    }
}
