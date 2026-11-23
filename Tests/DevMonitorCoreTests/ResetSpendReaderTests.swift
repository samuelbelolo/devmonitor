import DevMonitorCore
import XCTest

/// Spending a reset through the reader: once per click, never twice, and never alongside a renewal.
final class ResetSpendReaderTests: XCTestCase {
    private let key = UsageFakes.account.key
    private let clock = FakeClock()
    private let credit = ResetCredit(id: "g2", left: 1, clears: [.weekOnModel("Fable")], shownOn: .weekOnModel("Fable"), endsAt: nil)
    private let spent = FakeProvider.Reply.answer(200, Data(#"{"result": "reset", "resets_left": 0}"#.utf8))

    /// Returns a reader of this vault through this provider, on the test's clock.
    /// @example reader(vault, provider)
    private func reader(_ vault: SignInVault, _ provider: FakeProvider) -> UsageReader {
        let clock = clock
        return UsageReader(vault: vault, transport: provider, now: { clock.now })
    }

    /// The request id a spend request carries.
    /// @example requestID(request) // "req-1"
    private func requestID(_ request: URLRequest) -> String? {
        (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: String])?["request_id"]
    }

    func testAConfirmedSpendSendsOneRequest() async {
        let provider = FakeProvider(spend: [spent])
        let outcome = await reader(MemoryVault([UsageFakes.signIn("a1", "r1")]), provider).spend(credit, of: key, requestID: "req-1")
        XCTAssertEqual(outcome, .spent)
        let sent = await provider.sent("spend")
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first.flatMap(requestID), "req-1")
    }

    func testARefusedTokenIsRenewedAndTheSameRequestSentAgain() async throws {
        let vault = MemoryVault([UsageFakes.signIn("a1", "r1")])
        let provider = FakeProvider(renewal: [.answer(200, UsageFakes.tokenAnswer(access: "a2", refresh: "r2"))], spend: [.answer(401, Data()), spent])
        let outcome = await reader(vault, provider).spend(credit, of: key, requestID: "req-1")
        XCTAssertEqual(outcome, .spent)
        let sent = await provider.sent("spend")
        XCTAssertEqual(sent.map(requestID), ["req-1", "req-1"])
        XCTAssertEqual(try vault.signIn(for: key)?.refreshToken, "r2")
    }

    func testNoAnswerIsNeverRetriedAndLeavesTheOutcomeUnknown() async {
        let provider = FakeProvider(spend: [.offline, spent])
        let outcome = await reader(MemoryVault([UsageFakes.signIn("a1", "r1")]), provider).spend(credit, of: key, requestID: "req-1")
        XCTAssertEqual(outcome, .unknown)
        let sent = await provider.sent("spend")
        XCTAssertEqual(sent.count, 1)
        let failing = FakeProvider(spend: [.answer(502, Data()), spent])
        let again = await reader(MemoryVault([UsageFakes.signIn("a1", "r1")]), failing).spend(credit, of: key, requestID: "req-2")
        XCTAssertEqual(again, .unknown)
        let sentAgain = await failing.sent("spend")
        XCTAssertEqual(sentAgain.count, 1)
    }

    func testASpendWaitsForTheReadThatMayRenewTheToken() async throws {
        let vault = MemoryVault([UsageFakes.signIn("a1", "r1", accessLeft: 120)])
        let provider = FakeProvider(usage: [.answer(200, UsageFakes.usageAnswer)],
                                    renewal: [.answer(200, UsageFakes.tokenAnswer(access: "a2", refresh: "r2"))],
                                    spend: [spent], delay: .milliseconds(30))
        let reader = reader(vault, provider)
        async let read = reader.read(key)
        try await Task.sleep(for: .milliseconds(5))
        async let spend = reader.spend(credit, of: key, requestID: "req-1")
        _ = await (read, spend)
        let kinds = await provider.sent.map(FakeProvider.kind)
        XCTAssertEqual(kinds, ["renewal", "usage", "spend"])
        let renewals = await provider.sent("renewal")
        XCTAssertEqual(renewals.count, 1)
    }

    func testAReadForResetsAskedDuringAPlainReadIsSentAfterIt() async throws {
        let provider = FakeProvider(usage: [.answer(200, UsageFakes.usageAnswer)], delay: .milliseconds(30))
        let reader = reader(MemoryVault([UsageFakes.signIn("a1", "r1")]), provider)
        async let plain = reader.read(key)
        try await Task.sleep(for: .milliseconds(5))
        async let withResets = reader.read(key, withResets: true)
        _ = await (plain, withResets)
        let queries = await provider.sent("usage").map { $0.url?.query }
        XCTAssertEqual(queries, [nil, "cedar_ember=1"])
    }

    func testAPlainReadAskedDuringAReadForResetsJoinsIt() async throws {
        let provider = FakeProvider(usage: [.answer(200, UsageFakes.usageAnswer)], delay: .milliseconds(30))
        let reader = reader(MemoryVault([UsageFakes.signIn("a1", "r1")]), provider)
        async let withResets = reader.read(key, withResets: true)
        try await Task.sleep(for: .milliseconds(5))
        async let plain = reader.read(key)
        _ = await (withResets, plain)
        let sent = await provider.sent("usage")
        XCTAssertEqual(sent.count, 1)
    }

    func testARefusalAfterARenewalSaysWhatTheProviderAnswered() async {
        let refusal = FakeProvider.Reply.answer(401, Data(#"{"type": "error", "error": {"type": "authentication_error", "message": "not allowed for this token"}}"#.utf8))
        let provider = FakeProvider(renewal: [.answer(200, UsageFakes.tokenAnswer(access: "a2", refresh: "r2"))], spend: [refusal, refusal])
        let outcome = await reader(MemoryVault([UsageFakes.signIn("a1", "r1")]), provider).spend(credit, of: key, requestID: "req-1")
        XCTAssertEqual(outcome, .refused(status: 401, reason: "not allowed for this token"))
    }
}
