import DevMonitorCore
import XCTest

final class NextFreeAccountTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func usage(_ limits: [(Double, TimeInterval?)]) -> AccountUsage {
        AccountUsage(limits: limits.enumerated().map { AccountLimit(kind: .other("\($0.offset)"), percentUsed: $0.element.0, resetsAt: $0.element.1.map(now.addingTimeInterval)) })
    }

    func testTheSoonestAccountToComeBackWins() {
        let date = NextFreeAccount.date(of: [usage([(96, 3600)]), usage([(100, 600), (40, 60)])])
        XCTAssertEqual(date, now.addingTimeInterval(600))
    }

    func testAnAccountComesBackOnlyOnceAllItsFullLimitsHaveReset() {
        let date = NextFreeAccount.date(of: [usage([(97, 600), (95, 7200)]), usage([(99, 3600)])])
        XCTAssertEqual(date, now.addingTimeInterval(3600))
    }

    func testNothingShowsWhileAnAccountIsBelowTheCapOrUnread() {
        XCTAssertNil(NextFreeAccount.date(of: [usage([(96, 600)]), usage([(94.9, 60)])]))
        XCTAssertNil(NextFreeAccount.date(of: [usage([(96, 600)]), nil]))
        XCTAssertNil(NextFreeAccount.date(of: []))
    }

    func testAFullLimitWithoutAResetDateLeavesItsAccountOut() {
        XCTAssertEqual(NextFreeAccount.date(of: [usage([(96, nil)]), usage([(96, 900)])]), now.addingTimeInterval(900))
        XCTAssertNil(NextFreeAccount.date(of: [usage([(96, nil)])]))
    }
}
