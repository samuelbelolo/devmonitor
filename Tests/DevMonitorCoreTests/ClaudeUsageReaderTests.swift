import DevMonitorCore
import XCTest

final class ClaudeUsageReaderTests: XCTestCase {
    private let key = UsageFakes.account.key
    private let clock = FakeClock()
    private let ok = FakeProvider.Reply.answer(200, UsageFakes.usageAnswer)

    /// Returns a reader of this vault through this provider, on the test's clock.
    /// @example reader(vault, provider)
    private func reader(_ vault: SignInVault, _ provider: FakeProvider) -> UsageReader {
        let clock = clock
        return UsageReader(vault: vault, transport: provider, now: { clock.now })
    }

    /// The access token a request carries.
    /// @example bearer(request) // "a1"
    private func bearer(_ request: URLRequest?) -> String? {
        request?.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "")
    }

    func testAValidSignInIsReadWithOneRequest() async {
        let provider = FakeProvider(usage: [ok])
        let outcome = await reader(MemoryVault([UsageFakes.signIn("a1", "r1")]), provider).read(key)
        XCTAssertEqual(outcome, .read(try! ClaudeUsageAnswer.usage(from: UsageFakes.usageAnswer)))
        let sent = await provider.sent
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(bearer(sent.first), "a1")
    }

    func testAnAccessTokenAboutToEndIsRenewedAndSavedBeforeTheRead() async throws {
        let vault = MemoryVault([UsageFakes.signIn("a1", "r1", accessLeft: 120)])
        let provider = FakeProvider(usage: [ok], renewal: [.answer(200, UsageFakes.tokenAnswer(access: "a2", refresh: "r2"))])
        guard case .read = await reader(vault, provider).read(key) else { return XCTFail("not read") }
        let sent = await provider.sent
        XCTAssertEqual(sent.map(FakeProvider.kind), ["renewal", "usage"])
        XCTAssertEqual(bearer(sent.last), "a2")
        XCTAssertEqual(try vault.signIn(for: key)?.refreshToken, "r2")
    }

    func testARefusedAccessTokenIsRenewedOnceAndTheReadTriedAgain() async throws {
        let vault = MemoryVault([UsageFakes.signIn("a1", "r1")])
        let provider = FakeProvider(usage: [.answer(401, Data()), ok], renewal: [.answer(200, UsageFakes.tokenAnswer(access: "a2", refresh: "r2"))])
        guard case .read = await reader(vault, provider).read(key) else { return XCTFail("not read") }
        let kinds = await provider.sent.map(FakeProvider.kind)
        XCTAssertEqual(kinds, ["usage", "renewal", "usage"])
        XCTAssertEqual(try vault.signIn(for: key)?.accessToken, "a2")
    }

    func testAnAccessTokenRefusedAgainAfterARenewalAsksForANewSignIn() async {
        let provider = FakeProvider(usage: [.answer(401, Data())], renewal: [.answer(200, UsageFakes.tokenAnswer(access: "a2", refresh: "r2"))])
        let outcome = await reader(MemoryVault([UsageFakes.signIn("a1", "r1")]), provider).read(key)
        XCTAssertEqual(outcome, .needsSignIn)
        let renewals = await provider.sent("renewal").count
        XCTAssertEqual(renewals, 1)
    }

    func testARefusedRenewalAsksForANewSignInAndKeepsTheVaultAsItWas() async throws {
        let vault = MemoryVault([UsageFakes.signIn("a1", "r1", accessLeft: 0)])
        let provider = FakeProvider(renewal: [.answer(400, Data(#"{"error": "invalid_grant"}"#.utf8))])
        let outcome = await reader(vault, provider).read(key)
        XCTAssertEqual(outcome, .needsSignIn)
        XCTAssertEqual(try vault.signIn(for: key)?.refreshToken, "r1")
    }

    func testASignInPastItsDeadlineAsksForANewOneWithoutAnyRequest() async {
        clock.advance(by: 29 * 86_400)
        let provider = FakeProvider(usage: [ok])
        let outcome = await reader(MemoryVault([UsageFakes.signIn("a1", "r1")]), provider).read(key)
        XCTAssertEqual(outcome, .needsSignIn)
        let sent = await provider.sent
        XCTAssertTrue(sent.isEmpty)
    }

    func testAnAccountWithoutSignInAsksForOne() async {
        let outcome = await reader(MemoryVault(), FakeProvider()).read(key)
        XCTAssertEqual(outcome, .needsSignIn)
    }

    func testAThrottledReadWaitsAsToldBeforeAskingAgain() async {
        let provider = FakeProvider(usage: [.answer(429, Data(), ["retry-after": "120"]), ok])
        let reader = reader(MemoryVault([UsageFakes.signIn("a1", "r1")]), provider)
        let until = UsageFakes.start.addingTimeInterval(120)
        let first = await reader.read(key)
        XCTAssertEqual(first, .throttled(until: until))
        clock.advance(by: 60)
        let second = await reader.read(key)
        XCTAssertEqual(second, .throttled(until: until))
        clock.advance(by: 61)
        guard case .read = await reader.read(key) else { return XCTFail("not read after the wait") }
        let reads = await provider.sent("usage").count
        XCTAssertEqual(reads, 2)
    }

    func testAThrottledReadWithoutADelayWaitsTenMinutes() async {
        let provider = FakeProvider(usage: [.answer(429, Data())])
        let outcome = await reader(MemoryVault([UsageFakes.signIn("a1", "r1")]), provider).read(key)
        XCTAssertEqual(outcome, .throttled(until: UsageFakes.start.addingTimeInterval(600)))
    }

    func testAServerThatCannotBeReachedOrAnswersBadlyIsUnreachable() async {
        let offline = await reader(MemoryVault([UsageFakes.signIn("a1", "r1")]), FakeProvider(usage: [.offline])).read(key)
        XCTAssertEqual(offline, .unreachable)
        let broken = await reader(MemoryVault([UsageFakes.signIn("a1", "r1")]), FakeProvider(usage: [.answer(503, Data("<html>".utf8))])).read(key)
        XCTAssertEqual(broken, .unreachable)
        let garbled = await reader(MemoryVault([UsageFakes.signIn("a1", "r1")]), FakeProvider(usage: [.answer(200, Data("<html>".utf8))])).read(key)
        XCTAssertEqual(garbled, .unreachable)
    }

    func testARenewedPairThatCouldNotBeSavedIsStillUsedAndSavedOnTheNextRead() async throws {
        let vault = MemoryVault([UsageFakes.signIn("a1", "r1", accessLeft: 0)])
        vault.refuseSaves(1)
        let provider = FakeProvider(usage: [ok], renewal: [.answer(200, UsageFakes.tokenAnswer(access: "a2", refresh: "r2"))])
        let reader = reader(vault, provider)
        guard case .read = await reader.read(key) else { return XCTFail("not read") }
        XCTAssertEqual(try vault.signIn(for: key)?.refreshToken, "r1")
        guard case .read = await reader.read(key) else { return XCTFail("not read the second time") }
        XCTAssertEqual(try vault.signIn(for: key)?.refreshToken, "r2")
        let sent = await provider.sent
        XCTAssertEqual(sent.map(FakeProvider.kind), ["renewal", "usage", "usage"])
        XCTAssertEqual(bearer(sent.last), "a2")
    }

    func testTwoReadsAtOnceShareOneRenewal() async {
        let vault = MemoryVault([UsageFakes.signIn("a1", "r1", accessLeft: 0)])
        let provider = FakeProvider(usage: [ok], renewal: [.answer(200, UsageFakes.tokenAnswer(access: "a2", refresh: "r2"))], delay: .milliseconds(50))
        let reader = reader(vault, provider)
        async let first = reader.read(key)
        async let second = reader.read(key)
        let outcomes = await [first, second]
        XCTAssertEqual(outcomes.filter { if case .read = $0 { true } else { false } }.count, 2)
        let renewals = await provider.sent("renewal").count
        XCTAssertEqual(renewals, 1)
    }

    func testANewSignInIsSavedAndReplacesTheOneHeldForTheSameAccount() async throws {
        let vault = MemoryVault([UsageFakes.signIn("a1", "r1")])
        let provider = FakeProvider(usage: [ok])
        let reader = reader(vault, provider)
        try await reader.keep(UsageFakes.signIn("b1", "s1"))
        XCTAssertEqual(try vault.signIn(for: key)?.accessToken, "b1")
        _ = await reader.read(key)
        let sent = await provider.sent
        XCTAssertEqual(bearer(sent.last), "b1")
    }

    func testAForgottenAccountLeavesTheVault() async throws {
        let vault = MemoryVault([UsageFakes.signIn("a1", "r1")])
        let reader = reader(vault, FakeProvider(usage: [ok]))
        _ = await reader.read(key)
        try await reader.forget(key)
        XCTAssertNil(try vault.signIn(for: key))
        let outcome = await reader.read(key)
        XCTAssertEqual(outcome, .needsSignIn)
    }
}
