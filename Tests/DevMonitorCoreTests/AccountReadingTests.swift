import DevMonitorCore
import XCTest

final class AccountReadingTests: XCTestCase {
    private let start = UsageFakes.start

    /// Returns usage whose limits are at these shares.
    /// @example usage(15, 17).room // 83
    private func usage(_ percents: Double...) -> AccountUsage {
        AccountUsage(limits: percents.map { AccountLimit(kind: .week, percentUsed: $0, resetsAt: nil) })
    }

    func testAReadKeepsTheUsageAndItsTimeAndClearsTheProblem() {
        var reading = AccountReading(usage: nil, readAt: nil, problem: .unreachable)
        reading.apply(.read(usage(15, 17)), at: start)
        XCTAssertEqual(reading, AccountReading(usage: usage(15, 17), readAt: start, problem: nil))
    }

    func testAFailedReadKeepsTheLastUsageAndItsTime() {
        var reading = AccountReading(usage: usage(40), readAt: start, problem: nil)
        reading.apply(.unreachable, at: start.addingTimeInterval(600))
        XCTAssertEqual(reading.usage, usage(40))
        XCTAssertEqual(reading.readAt, start)
        XCTAssertEqual(reading.problem, .unreachable)
        reading.apply(.needsSignIn, at: start.addingTimeInterval(1200))
        XCTAssertEqual(reading.problem, .needsSignIn)
        reading.apply(.throttled(until: start.addingTimeInterval(1800)), at: start.addingTimeInterval(1200))
        XCTAssertEqual(reading.problem, .throttled(until: start.addingTimeInterval(1800)))
    }

    func testAReadingIsDueAfterTwoMinutesOrWhenNeverRead() {
        XCTAssertTrue(AccountReading.empty.isDue(at: start))
        let reading = AccountReading(usage: usage(10), readAt: start, problem: nil)
        XCTAssertFalse(reading.isDue(at: start.addingTimeInterval(120)))
        XCTAssertTrue(reading.isDue(at: start.addingTimeInterval(121)))
    }

    func testTheCountIsTheAccountsWhoseEveryLimitIsUnderNinetyFive() {
        let count = RoomCount.of([usage(15, 17), usage(94.9), usage(95), usage(20, 99), nil, usage()])
        XCTAssertEqual(count.withRoom, 2)
        XCTAssertEqual(count.total, 6)
    }

    func testANewSignInOfATrackedAccountReplacesItAndKeepsItsName() {
        let first = TrackedAccount(account: UsageFakes.account, name: "Perso", signInEndsAt: start)
        let other = AccountID(account: "a", organization: "o", email: "other@example.com")
        let renewedEmail = AccountID(account: UsageFakes.account.account, organization: UsageFakes.account.organization, email: "new@example.com")
        let later = start.addingTimeInterval(86_400)
        let list = TrackedAccount.adding(renewedEmail, signInEndsAt: later, to: [first, TrackedAccount(account: other, name: nil, signInEndsAt: nil)])
        XCTAssertEqual(list.map(\.account.email), ["new@example.com", "other@example.com"])
        XCTAssertEqual(list[0].name, "Perso")
        XCTAssertEqual(list[0].signInEndsAt, later)
        let added = TrackedAccount.adding(other, signInEndsAt: nil, to: [first])
        XCTAssertEqual(added.map(\.id), [first.id, other.key])
    }

    func testANameGivenAtSignInIsKeptAndNoNameKeepsTheOneAlreadyGiven() {
        let first = TrackedAccount(account: UsageFakes.account, name: "Perso", signInEndsAt: nil)
        XCTAssertEqual(TrackedAccount.adding(UsageFakes.account, name: "Boulot", signInEndsAt: nil, to: [first])[0].name, "Boulot")
        XCTAssertEqual(TrackedAccount.adding(UsageFakes.account, name: nil, signInEndsAt: nil, to: [first])[0].name, "Perso")
        XCTAssertEqual(TrackedAccount.adding(UsageFakes.account, name: "New", signInEndsAt: nil, to: [])[0].name, "New")
    }

    func testAnAccountIsCalledByItsNameOrElseItsEmail() {
        XCTAssertEqual(TrackedAccount(account: UsageFakes.account, name: "Perso", signInEndsAt: nil).title, "Perso")
        XCTAssertEqual(TrackedAccount(account: UsageFakes.account, name: "  ", signInEndsAt: nil).title, "dev@example.com")
        XCTAssertEqual(TrackedAccount(account: UsageFakes.account, name: nil, signInEndsAt: nil).title, "dev@example.com")
    }

    func testTheTrackedAccountsSurviveARelaunch() throws {
        let accounts = [TrackedAccount(account: UsageFakes.account, name: "Perso", signInEndsAt: start)]
        let suite = "local.devmonitor.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        TrackedAccount.save(accounts, to: defaults)
        XCTAssertEqual(TrackedAccount.load(from: defaults), accounts)
        XCTAssertEqual(TrackedAccount.load(from: try XCTUnwrap(UserDefaults(suiteName: suite + ".empty"))), [])
    }
}
