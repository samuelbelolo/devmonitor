@testable import DevMonitorCore
import XCTest

/// Reading the free resets out of the providers' answers. Every fixture is written by hand.
final class ResetCreditTests: XCTestCase {
    private let limits = #""limits": [{"kind": "weekly_all", "percent": 35, "resets_at": "2026-11-21T04:00:00+00:00", "scope": null}, {"kind": "weekly_scoped", "percent": 23, "resets_at": "2026-11-21T04:00:00+00:00", "scope": {"model": {"display_name": "Fable"}}}]"#

    /// Returns a Claude grant as the usage answer lists it.
    /// @example grant("g1", left: 1, clears: ["seven_day"]) // {"id": "g1", …}
    private func grant(_ id: String, left: Int, clears: [String], usable: Bool = true, paused: Bool = false) -> String {
        let names = clears.map { "\"\($0)\"" }.joined(separator: ", ")
        return #"{"id": "\#(id)", "label": "A reset", "type": "full", "resets_total": 1, "resets_left": \#(left), "ends_at": "2027-03-09T07:59:00+00:00", "clears": [\#(names)], "paused": \#(paused), "usable_now": \#(usable), "use_requires_limit": false}"#
    }

    /// Returns a Claude usage answer with these grants, or with `block` as its `cedar_ember` value.
    /// @example claudeAnswer(grants: [grant("g1", left: 1, clears: ["seven_day"])])
    private func claudeAnswer(grants: [String]? = nil, block: String? = nil) -> Data {
        let ember = block ?? #"{"eligible": true, "next_grant_id": "g2", "grants": [\#((grants ?? []).joined(separator: ", "))]}"#
        return Data(#"{"five_hour": null, \#(limits), "cedar_ember": \#(ember)}"#.utf8)
    }

    func testAClaudeGrantShowsOnTheGaugeItStartsAgain() throws {
        let body = claudeAnswer(grants: [
            grant("g1", left: 1, clears: ["seven_day", "seven_day_overage_included"]),
            grant("g2", left: 1, clears: ["seven_day_overage_included"]),
            grant("g3", left: 1, clears: ["seven_day_overage_included"]),
        ])
        let credits = try XCTUnwrap(ClaudeUsageAnswer.usage(from: body).resetCredits)
        XCTAssertEqual(credits.map(\.id), ["g2", "g1", "g3"], "the provider's next grant comes first")
        let week = try XCTUnwrap(credits.first { $0.id == "g1" })
        XCTAssertEqual(week.shownOn, .week)
        XCTAssertEqual(week.clears, [.week, .weekOnModel("Fable")])
        let fable = try XCTUnwrap(credits.first { $0.id == "g2" })
        XCTAssertEqual(fable.shownOn, .weekOnModel("Fable"))
        XCTAssertEqual(fable.endsAt, Timestamp.date("2027-03-09T07:59:00+00:00"))
        let usage = try ClaudeUsageAnswer.usage(from: body)
        XCTAssertEqual(usage.resetsLeft(on: .week), 1)
        XCTAssertEqual(usage.resetsLeft(on: .weekOnModel("Fable")), 2)
    }

    func testSpentPausedOrUnusableGrantsAreLeftOut() throws {
        let body = claudeAnswer(grants: [
            grant("g1", left: 0, clears: ["seven_day"]),
            grant("g2", left: 1, clears: ["seven_day_overage_included"], paused: true),
            grant("g3", left: 1, clears: ["seven_day_overage_included"], usable: false),
        ])
        XCTAssertEqual(try ClaudeUsageAnswer.usage(from: body).resetCredits, [])
    }

    func testAGrantOnALimitDevMonitorDoesNotKnowShowsOnTheAccount() throws {
        let credits = try XCTUnwrap(ClaudeUsageAnswer.usage(from: claudeAnswer(grants: [grant("g1", left: 1, clears: ["seven_day_sonnet"])])).resetCredits)
        XCTAssertEqual(credits.first?.shownOn, nil)
        XCTAssertEqual(credits.first?.clears, [.other("seven_day_sonnet")])
    }

    func testTheProvidersNextGrantIsSpentFirst() throws {
        let usage = try ClaudeUsageAnswer.usage(from: claudeAnswer(grants: [
            grant("g1", left: 1, clears: ["seven_day_overage_included"]),
            grant("g2", left: 1, clears: ["seven_day_overage_included"]),
        ]))
        XCTAssertEqual(usage.nextCredit(on: .weekOnModel("Fable"))?.id, "g2")
    }

    func testAnAnswerWithoutTheBlockSaysNothingAboutResets() throws {
        XCTAssertNil(try ClaudeUsageAnswer.usage(from: claudeAnswer(block: "null")).resetCredits)
        XCTAssertNil(try ClaudeUsageAnswer.usage(from: Data(#"{\#(limits)}"#.utf8)).resetCredits)
    }

    func testCodexCreditsStartEveryLimitAgainAndShowOnTheLongest() throws {
        let body = Data(#"{"rate_limit": {"primary_window": {"used_percent": 55, "limit_window_seconds": 604800, "reset_at": 1795008058}}, "rate_limit_reset_credits": {"available_count": 3, "applicable_available_count": 0}}"#.utf8)
        let usage = try CodexUsageAnswer.usage(from: body)
        XCTAssertEqual(usage.resetCredits, [ResetCredit(id: nil, left: 3, clears: [], shownOn: .week, endsAt: nil)])
        XCTAssertEqual(usage.resetsLeft(on: .week), 3)
        let none = Data(#"{"rate_limit": {"primary_window": {"used_percent": 55, "limit_window_seconds": 604800, "reset_at": 1795008058}}}"#.utf8)
        XCTAssertNil(try CodexUsageAnswer.usage(from: none).resetCredits)
    }

    func testAReadWithoutResetsKeepsTheResetsReadBefore() throws {
        let withResets = try ClaudeUsageAnswer.usage(from: claudeAnswer(grants: [grant("g2", left: 1, clears: ["seven_day_overage_included"])]))
        let plain = try ClaudeUsageAnswer.usage(from: Data(#"{\#(limits)}"#.utf8))
        var reading = AccountReading.empty
        reading.apply(.read(withResets), at: UsageFakes.start)
        reading.apply(.read(plain), at: UsageFakes.start.addingTimeInterval(600))
        XCTAssertEqual(reading.usage?.resetsLeft(on: .weekOnModel("Fable")), 1)
        XCTAssertEqual(reading.creditsReadAt, UsageFakes.start)
        let none = try ClaudeUsageAnswer.usage(from: claudeAnswer(grants: []))
        reading.apply(.read(none), at: UsageFakes.start.addingTimeInterval(700))
        XCTAssertEqual(reading.usage?.resetsLeft(on: .weekOnModel("Fable")), 0)
    }

    func testOnlyTheReadThatAsksForResetsCallsItselfClaudeCode() {
        let plain = ClaudeEndpoints.usage(accessToken: "a", withResets: false)
        XCTAssertNil(plain.url?.query)
        XCTAssertNil(plain.value(forHTTPHeaderField: "User-Agent"))
        let resets = ClaudeEndpoints.usage(accessToken: "a", withResets: true)
        XCTAssertEqual(resets.url?.query, "cedar_ember=1")
        XCTAssertEqual(resets.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("claude-cli/"), true)
        XCTAssertEqual(resets.value(forHTTPHeaderField: "User-Agent")?.hasSuffix(" (external, cli)"), true)
    }

    func testTheSpendRequestsCarryTheGrantAndTheRequestId() throws {
        let claude = ClaudeEndpoints.spendReset(accessToken: "a", organization: "org-1", grantID: "g2", requestID: "req-1")
        XCTAssertEqual(claude.httpMethod, "POST")
        XCTAssertEqual(claude.url?.absoluteString, "https://api.anthropic.com/api/organizations/org-1/reset_rate_limits")
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: claude.httpBody ?? Data()) as? [String: String])
        XCTAssertEqual(fields, ["program": "cedar_ember", "grant_id": "g2", "request_id": "req-1"])
        let codex = CodexEndpoints.spendReset(accessToken: "a", accountID: "cx-1", requestID: "req-2")
        XCTAssertEqual(codex.url?.absoluteString, "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits/consume")
        XCTAssertEqual(codex.value(forHTTPHeaderField: "ChatGPT-Account-ID"), "cx-1")
        let codexFields = try XCTUnwrap(JSONSerialization.jsonObject(with: codex.httpBody ?? Data()) as? [String: String])
        XCTAssertEqual(codexFields, ["redeem_request_id": "req-2"])
    }

    func testTheSpendAnswersSayWhetherTheResetWasUsed() {
        let claude = ClaudeService()
        XCTAssertEqual(claude.spendOutcome(status: 200, body: Data(#"{"result": "reset", "resets_left": 0}"#.utf8)), .spent)
        XCTAssertEqual(claude.spendOutcome(status: 200, body: Data(#"{"result": "not_reset", "reason": "cooldown"}"#.utf8)), .refused(status: 200, reason: "cooldown"))
        XCTAssertEqual(claude.spendOutcome(status: 403, body: Data(#"{"error": {"message": "insufficient scope"}}"#.utf8)), .refused(status: 403, reason: "insufficient scope"))
        XCTAssertEqual(claude.spendOutcome(status: 500, body: Data()), .unknown)
        let codex = CodexService()
        XCTAssertEqual(codex.spendOutcome(status: 200, body: Data(#"{"code": "reset", "windows_reset": 1}"#.utf8)), .spent)
        XCTAssertEqual(codex.spendOutcome(status: 200, body: Data(#"{"code": "already_redeemed"}"#.utf8)), .spent)
        XCTAssertEqual(codex.spendOutcome(status: 200, body: Data(#"{"code": "nothing_to_reset"}"#.utf8)), .nothingToReset)
        XCTAssertEqual(codex.spendOutcome(status: 200, body: Data(#"{"code": "no_credit"}"#.utf8)), .noneLeft)
    }
}
