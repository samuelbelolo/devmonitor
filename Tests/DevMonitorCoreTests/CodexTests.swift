import DevMonitorCore
import XCTest

/// The answers below are written by hand from the shape of a real one: only the keys the reader uses, with made-up
/// values.
final class CodexTests: XCTestCase {
    private let start = UsageFakes.start
    private let account = AccountID(provider: .codex, account: "4f1c2d3e-aaaa-bbbb-cccc-1234567890ab", organization: "", email: "dev@example.com")

    /// Returns an unsigned JWT carrying these claims.
    /// @example jwt(["exp": 1]) // "e30.eyJleHAiOjF9.c2ln"
    private func jwt(_ claims: [String: Any]) -> String {
        let payload = try! JSONSerialization.data(withJSONObject: claims).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return "e30.\(payload).c2ln"
    }

    /// Returns a token answer as OpenAI gives it, with or without an id token.
    /// @example tokenAnswer(access: "a1", refresh: "r1") // {"access_token": "a1", …}
    private func tokenAnswer(access: String, refresh: String?, withIdentity: Bool = true) -> Data {
        var answer: [String: Any] = ["access_token": access, "token_type": "Bearer", "expires_in": 864_000, "scope": "openid profile email offline_access",
                                     "earliest_refresh_at": Int(start.timeIntervalSince1970) + 777_600]
        if let refresh { answer["refresh_token"] = refresh }
        if withIdentity {
            answer["id_token"] = jwt(["email": account.email, "https://api.openai.com/auth": ["chatgpt_account_id": account.account, "chatgpt_plan_type": "plus"]])
        }
        return try! JSONSerialization.data(withJSONObject: answer)
    }

    /// Returns a usage answer with these windows, each as (seconds, percent), the second one optional.
    /// @example usageAnswer((604_800, 55)) // {"rate_limit": {"primary_window": {…}, "secondary_window": null}}
    private func usageAnswer(_ primary: (Int, Double), _ secondary: (Int, Double)? = nil) -> Data {
        func window(_ window: (Int, Double)) -> [String: Any] {
            ["used_percent": window.1, "limit_window_seconds": window.0, "reset_after_seconds": 1000, "reset_at": Int(start.timeIntervalSince1970) + 1000]
        }
        let limit: [String: Any] = ["allowed": true, "limit_reached": false, "primary_window": window(primary), "secondary_window": secondary.map(window) ?? NSNull()]
        return try! JSONSerialization.data(withJSONObject: ["plan_type": "plus", "rate_limit": limit, "additional_rate_limits": NSNull()])
    }

    func testTheAuthorizationPageIsTheCodexClients() throws {
        let method = CodexSignInMethod()
        XCTAssertEqual(method.ports, [1455, 1457])
        XCTAssertEqual(method.callbackPath, "/auth/callback")
        XCTAssertEqual(method.redirectURI(port: 1455), "http://127.0.0.1:1455/auth/callback")
        let url = method.authorize(redirectURI: "http://127.0.0.1:1455/auth/callback", challenge: "c", state: "s")
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(url.host, "auth.openai.com")
        XCTAssertEqual(query["client_id"], CodexEndpoints.clientID)
        XCTAssertEqual(query["scope"], "openid profile email offline_access")
        XCTAssertEqual(query["redirect_uri"], "http://127.0.0.1:1455/auth/callback")
        XCTAssertEqual(query["code_challenge_method"], "S256")
        XCTAssertEqual(query["originator"], "codex_cli_rs")
        XCTAssertEqual(query["id_token_add_organizations"], "true")
        XCTAssertEqual(query["codex_cli_simplified_flow"], "true")
        XCTAssertEqual(query["state"], "s")
    }

    func testTheExchangeIsAFormAndTheRenewalIsJSON() throws {
        let exchange = CodexSignInMethod().exchange(code: "k", state: "s", verifier: "v", redirectURI: "http://127.0.0.1:1455/auth/callback")
        XCTAssertEqual(exchange.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        let form = String(decoding: exchange.httpBody ?? Data(), as: UTF8.self)
        let fields = Dictionary(uniqueKeysWithValues: (URLComponents(string: "?" + form)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(fields, ["grant_type": "authorization_code", "client_id": CodexEndpoints.clientID, "code": "k",
                                "redirect_uri": "http://127.0.0.1:1455/auth/callback", "code_verifier": "v"])
        let renewal = CodexService().renewal(of: SignIn(accessToken: "a", refreshToken: "r", accessExpiresAt: start, expiresAt: nil, account: account))
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: renewal.httpBody ?? Data()) as? [String: String])
        XCTAssertEqual(body, ["client_id": CodexEndpoints.clientID, "grant_type": "refresh_token", "refresh_token": "r"])
    }

    func testTheUsageReadSendsTheTokenOnly() {
        let request = CodexService().usageRequest(for: SignIn(accessToken: "a", refreshToken: "r", accessExpiresAt: start, expiresAt: nil, account: account))
        XCTAssertEqual(request.url?.absoluteString, "https://chatgpt.com/backend-api/wham/usage")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer a")
        XCTAssertNil(request.value(forHTTPHeaderField: "User-Agent"))
        XCTAssertNil(request.value(forHTTPHeaderField: "chatgpt-account-id"))
    }

    func testASignInReadsTheAccountFromTheIdTokenAndTheRenewalDate() throws {
        let signIn = try CodexSignInMethod().signIn(from: tokenAnswer(access: "a1", refresh: "r1"), receivedAt: start)
        XCTAssertEqual(signIn.account, account)
        XCTAssertEqual(signIn.account.key, "codex:4f1c2d3e-aaaa-bbbb-cccc-1234567890ab:")
        XCTAssertEqual(signIn.accessExpiresAt, start.addingTimeInterval(864_000))
        XCTAssertEqual(signIn.renewAfter, start.addingTimeInterval(777_600))
        XCTAssertNil(signIn.expiresAt)
        XCTAssertTrue(signIn.isAccessDue(at: start.addingTimeInterval(777_600)))
        XCTAssertFalse(signIn.isAccessDue(at: start.addingTimeInterval(777_599)))
    }

    func testARenewalWithoutIdTokenOrRefreshTokenKeepsThePreviousOnes() throws {
        let previous = SignIn(accessToken: "a1", refreshToken: "r1", accessExpiresAt: start, expiresAt: nil, account: account)
        let renewed = try CodexService().renewed(from: tokenAnswer(access: "a2", refresh: nil, withIdentity: false), receivedAt: start, previous: previous)
        XCTAssertEqual(renewed.accessToken, "a2")
        XCTAssertEqual(renewed.refreshToken, "r1")
        XCTAssertEqual(renewed.account, account)
    }

    func testASignInWithoutAccountIsRefused() {
        XCTAssertThrowsError(try CodexSignInMethod().signIn(from: tokenAnswer(access: "a1", refresh: "r1", withIdentity: false), receivedAt: start))
    }

    func testEachWindowIsNamedByItsDurationNotItsSlot() throws {
        let weekOnly = try CodexService().usage(from: usageAnswer((604_800, 55)))
        XCTAssertEqual(weekOnly.limits.map(\.kind), [.week])
        XCTAssertEqual(weekOnly.limits.map(\.percentUsed), [55])
        XCTAssertEqual(weekOnly.limits.first?.resetsAt, start.addingTimeInterval(1000))
        let both = try CodexService().usage(from: usageAnswer((18_000, 12), (604_800, 40)))
        XCTAssertEqual(both.limits.map(\.kind), [.fiveHours, .week])
        let weekFirst = try CodexService().usage(from: usageAnswer((604_800, 40), (18_000, 90)))
        XCTAssertEqual(weekFirst.limits.map(\.kind), [.week, .fiveHours])
        XCTAssertEqual(weekFirst.fullest?.kind, .fiveHours)
        let day = try CodexService().usage(from: usageAnswer((86_400, 5)))
        XCTAssertEqual(day.limits.map(\.kind), [.window(seconds: 86_400)])
    }

    func testAnAnswerWithoutRateLimitHasNoLimitAndAnotherShapeIsRefused() throws {
        XCTAssertEqual(try CodexService().usage(from: Data(#"{"plan_type": "free", "rate_limit": null}"#.utf8)).limits, [])
        XCTAssertThrowsError(try CodexService().usage(from: Data("<html>".utf8)))
    }

    func testTheReaderRenewsACodexSignInOnItsRenewalDateAndKeepsTheNewPair() async throws {
        let clock = FakeClock()
        let held = SignIn(accessToken: "a1", refreshToken: "r1", accessExpiresAt: start.addingTimeInterval(864_000), expiresAt: nil, account: account, renewAfter: start.addingTimeInterval(60))
        let vault = MemoryVault([held])
        let provider = FakeProvider(usage: [.answer(200, usageAnswer((604_800, 55)))], renewal: [.answer(200, tokenAnswer(access: "a2", refresh: "r2"))])
        let reader = UsageReader(vault: vault, transport: provider, services: [.claude: ClaudeService(), .codex: CodexService()], now: { clock.now })
        guard case .read(let first) = await reader.read(account.key) else { return XCTFail("not read") }
        XCTAssertEqual(first.limits.map(\.kind), [.week])
        let beforeRenewal = await provider.sent("renewal").count
        XCTAssertEqual(beforeRenewal, 0)
        clock.advance(by: 61)
        guard case .read = await reader.read(account.key) else { return XCTFail("not read after the renewal date") }
        let renewals = await provider.sent("renewal")
        XCTAssertEqual(renewals.count, 1)
        XCTAssertEqual(renewals.first?.url?.host, "auth.openai.com")
        XCTAssertEqual(try vault.signIn(for: account.key)?.refreshToken, "r2")
        let lastRead = await provider.sent("usage").last
        XCTAssertEqual(lastRead?.value(forHTTPHeaderField: "Authorization"), "Bearer a2")
    }
}
