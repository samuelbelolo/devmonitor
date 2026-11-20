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
        store.startSignIn(.claude)
        store.startSignIn(.codex)
        store.refreshNow()
        XCTAssertFalse(store.isRefreshing)
        XCTAssertEqual(store.readings, readings)
        XCTAssertEqual(store.signInStep, .idle)
    }

    func testClaudesAccountsComeFirstEachProvidersWithTheMostRoomFirst() {
        let store = SampleUsage.store()
        XCTAssertEqual(store.sortedAccounts(of: .claude).map(\.title), ["clients@example.com", "Personal", "Team", "labs@example.com", "work@example.com"])
        XCTAssertEqual(store.sortedAccounts.map(\.account.provider), [.claude, .claude, .claude, .claude, .claude, .codex])
        XCTAssertEqual(store.codexFullest, 55)
        XCTAssertTrue(store.follows(.codex))
    }

    func testEachProviderSignsInItsOwnWay() {
        XCTAssertEqual(UsageStore.signInMethod(for: .codex).ports, [1455, 1457])
        XCTAssertEqual(UsageStore.signInMethod(for: .codex).callbackPath, "/auth/callback")
        XCTAssertEqual(UsageStore.signInMethod(for: .claude).ports, [])
    }

    func testTheMenuBarShowsEachFollowedProviderAndNeverAnEmptyFigure() {
        typealias Part = UsageMenuBarLabel.Part
        XCTAssertEqual(UsageMenuBarLabel.parts(followsClaude: true, claudePercent: 17, followsCodex: false, codexFullest: nil), [Part(agent: .claude, text: "17\u{00A0}%", tint: nil)])
        XCTAssertEqual(UsageMenuBarLabel.parts(followsClaude: false, claudePercent: nil, followsCodex: true, codexFullest: 55), [Part(agent: .codex, text: "55\u{00A0}%", tint: nil)])
        XCTAssertEqual(UsageMenuBarLabel.parts(followsClaude: true, claudePercent: 82, followsCodex: true, codexFullest: 96),
                       [Part(agent: .claude, text: "82\u{00A0}%", tint: LimitTint.color(percentUsed: 82)), Part(agent: .codex, text: "96\u{00A0}%", tint: Palette.orphan)])
        XCTAssertEqual(UsageMenuBarLabel.parts(followsClaude: true, claudePercent: nil, followsCodex: true, codexFullest: nil),
                       [Part(agent: .claude, text: "–", tint: nil), Part(agent: .codex, text: "–", tint: nil)])
        XCTAssertEqual(UsageMenuBarLabel.parts(followsClaude: false, claudePercent: nil, followsCodex: false, codexFullest: nil), [Part(agent: .claude, text: "+", tint: nil)])
        XCTAssertEqual(UsageMenuBarLabel.parts(followsClaude: true, claudePercent: 97, followsCodex: false, codexFullest: nil, claudeFreeIn: 6_119.4),
                       [Part(agent: .claude, text: "97\u{00A0}%", tint: Palette.orphan, detail: UsageStrings.countdown(6_120))])
        XCTAssertEqual(UsageMenuBarLabel.tint(percentUsed: 80), LimitTint.orange)
        XCTAssertNotNil(UsageMenuBarLabel.tint(percentUsed: 88))
        XCTAssertNotEqual(UsageMenuBarLabel.tint(percentUsed: 88), LimitTint.orange)
        XCTAssertEqual(UsageMenuBarLabel.tint(percentUsed: 95), Palette.orphan)
        XCTAssertNil(UsageMenuBarLabel.tint(percentUsed: 79))
    }

    func testAFigureNeverBreaksFromItsUnitAtTheEndOfALine() {
        for text in [UsageStrings.countdown(394_380), UsageStrings.countdown(7_800), UsageMenuBarLabel.text(percentUsed: 17)] {
            XCTAssertFalse(text.contains(" "), text)
        }
        for text in [UsageStrings.used(15), ResetStrings.confirmTitle, ResetStrings.littleUsed(under: 10), UsageStrings.signedIn("dev@example.com")] {
            XCTAssertNil(text.range(of: #" [?:%]"#, options: .regularExpression), text)
        }
    }

    func testTheMenuBarShowsTheAccountMostSessionsDrawOn() {
        let store = SampleUsage.store()
        XCTAssertEqual(store.busiestClaudePercent, 17)
        store.noteSessions(["1-1": store.accounts[1].id, "2-1": store.accounts[1].id, "3-1": store.accounts[0].id])
        XCTAssertEqual(store.busiestClaudePercent, 96)
        store.noteSessions([:])
        XCTAssertNil(store.busiestClaudePercent)
        store.noteDefaultAccount(store.accounts[5].id)
        XCTAssertEqual(store.busiestClaudePercent, 61)
    }

    func testRenamingAndRemovingChangeOnlyTheSampleStore() {
        let store = SampleUsage.store()
        let work = store.accounts[1]
        store.rename(work, to: "  Boulot ")
        XCTAssertEqual(store.accounts[1].title, "Boulot")
        store.rename(store.accounts[1], to: " ")
        XCTAssertEqual(store.accounts[1].title, "work@example.com")
        store.remove(store.accounts[1])
        XCTAssertEqual(store.accounts.map(\.title), ["Personal", "Team", "Personal", "clients@example.com", "labs@example.com"])
        XCTAssertNil(store.readings[work.id])
    }

    func testCountsTheRunningSessionsOnEachAccount() {
        let store = UsageStore(sample: [], readings: [:])
        store.noteSessions(["1-1": "acc:org", "2-1": "acc:org", "3-1": "codex:cx:"])
        XCTAssertEqual(store.runningSessions, ["acc:org": 2, "codex:cx:": 1])
        store.noteSessions([:])
        XCTAssertEqual(store.runningSessions, [:])
    }

    func testTheLabelSaysHowManySessionsRun() {
        XCTAssertTrue(["en cours · 1\u{00A0}session", "in use · 1\u{00A0}session"].contains(UsageStrings.inUse(1)))
        XCTAssertTrue(["en cours · 12\u{00A0}sessions", "in use · 12\u{00A0}sessions"].contains(UsageStrings.inUse(12)))
    }

    func testTheSampleStoreNeverSpendsAReset() async throws {
        let store = SampleUsage.store(confirming: false)
        let perso = try XCTUnwrap(store.accounts.first { store.reading(of: $0).usage?.resetsLeft(on: .weekOnModel("Fable")) == 1 })
        store.prepareSpend(of: perso)
        store.spendReset(on: .weekOnModel("Fable"), of: perso)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(store.spending.isEmpty)
        XCTAssertTrue(store.spendOutcomes.isEmpty)
        XCTAssertEqual(store.reading(of: perso).usage?.resetsLeft(on: .weekOnModel("Fable")), 1)
    }
}
