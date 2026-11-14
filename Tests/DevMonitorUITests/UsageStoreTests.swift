import DevMonitorCore
import XCTest
@testable import DevMonitorUI

/// The sample store is rendered on a developer's Mac: if it read the keychain or the network, it would renew the app's
/// sign-ins behind its back and end them. These tests fail if it reads, signs in or keeps anything.
@MainActor
final class UsageStoreTests: XCTestCase {
    func testTheSampleStoreReadsNothingAndKeepsItsReadings() async {
        let store = SampleUsage.store()
        let readings = store.readings
        store.windowOpened()
        await store.readAll(spread: false)
        for account in store.accounts { await store.read(account.id) }
        store.startSignIn()
        XCTAssertEqual(store.readings, readings)
        XCTAssertEqual(store.signInStep, .idle)
    }

    func testTheAccountsWithTheMostRoomComeFirst() {
        let titles = SampleUsage.store().sortedAccounts.map(\.title)
        XCTAssertEqual(titles, ["Perso", "Team", "work@example.com"])
    }

    func testTheMenuBarCountsTheAccountsWithRoomAndColorsTheLastOne() {
        let count = SampleUsage.store().roomCount
        XCTAssertEqual(count.withRoom, 2)
        XCTAssertEqual(count.total, 3)
        XCTAssertNil(UsageMenuBarLabel.tint(withRoom: 2, total: 3))
        XCTAssertEqual(UsageMenuBarLabel.tint(withRoom: 1, total: 3), Palette.idle)
        XCTAssertEqual(UsageMenuBarLabel.tint(withRoom: 0, total: 3), Palette.orphan)
        XCTAssertNil(UsageMenuBarLabel.tint(withRoom: 0, total: 0))
        XCTAssertEqual(UsageMenuBarLabel.text(withRoom: 2, total: 3), "2/3")
        XCTAssertEqual(UsageMenuBarLabel.text(withRoom: 0, total: 0), "+")
    }

    func testRenamingAndRemovingChangeOnlyTheSampleStore() {
        let store = SampleUsage.store()
        let work = store.accounts[1]
        store.rename(work, to: "  Boulot ")
        XCTAssertEqual(store.accounts[1].title, "Boulot")
        store.rename(store.accounts[1], to: " ")
        XCTAssertEqual(store.accounts[1].title, "work@example.com")
        store.remove(store.accounts[1])
        XCTAssertEqual(store.accounts.map(\.title), ["Perso", "Team"])
        XCTAssertNil(store.readings[work.id])
    }
}
