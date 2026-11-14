import DevMonitorCore
import XCTest

final class ClaudeSignInTests: XCTestCase {
    func testTheChallengeIsTheOneAnotherImplementationComputes() {
        // Computed with Python: base64.urlsafe_b64encode(hashlib.sha256(verifier).digest()) without its padding.
        XCTAssertEqual(PKCE.challenge(for: "dBjftJeZ4CVP-mJ92K1qqh8V3JK6-yHlnTOp1qBfBHA"), "bU69_A-JQYKr9sWEgXSMqYHToy0G1baYIqxmsXRLoks")
        let pair = PKCE.make()
        XCTAssertEqual(pair.verifier.count, 43)
        XCTAssertNil(pair.verifier.rangeOfCharacter(from: CharacterSet(charactersIn: "+/=")))
        XCTAssertEqual(pair.challenge, PKCE.challenge(for: pair.verifier))
        XCTAssertNotEqual(PKCE.make().verifier, pair.verifier)
    }

    func testTheAuthorizationPageAsksToReadTheProfileOnly() throws {
        let url = ClaudeEndpoints.authorize(redirectURI: "http://localhost:4321/callback", challenge: "c", state: "s")
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(url.host, "claude.ai")
        XCTAssertEqual(query["scope"], "user:profile")
        XCTAssertEqual(query["client_id"], ClaudeEndpoints.clientID)
        XCTAssertEqual(query["redirect_uri"], "http://localhost:4321/callback")
        XCTAssertEqual(query["code_challenge_method"], "S256")
        XCTAssertEqual(query["response_type"], "code")
        XCTAssertEqual(query["state"], "s")
    }

    func testTheExchangeAndTheRenewalSendWhatTheProviderExpects() throws {
        let exchange = ClaudeEndpoints.exchange(code: "k", state: "s", verifier: "v", redirectURI: "http://localhost:1/callback")
        let sent = try XCTUnwrap(JSONSerialization.jsonObject(with: exchange.httpBody ?? Data()) as? [String: String])
        XCTAssertEqual(exchange.httpMethod, "POST")
        XCTAssertEqual(sent, ["code": "k", "state": "s", "grant_type": "authorization_code", "client_id": ClaudeEndpoints.clientID,
                              "redirect_uri": "http://localhost:1/callback", "code_verifier": "v"])
        let renewal = ClaudeEndpoints.renewal(refreshToken: "r")
        let renewed = try XCTUnwrap(JSONSerialization.jsonObject(with: renewal.httpBody ?? Data()) as? [String: String])
        XCTAssertEqual(renewed, ["grant_type": "refresh_token", "refresh_token": "r", "client_id": ClaudeEndpoints.clientID])
    }

    func testTheUsageReadDoesNotCallItselfClaudeCode() {
        let request = ClaudeEndpoints.usage(accessToken: "a")
        XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/api/oauth/usage")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer a")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "oauth-2025-04-20")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertNil(request.value(forHTTPHeaderField: "User-Agent"))
    }

    func testATokenAnswerGivesTheSignInItsDeadlinesAndTheAccount() throws {
        let signIn = try ClaudeTokenAnswer.signIn(from: UsageFakes.tokenAnswer(access: "a", refresh: "r"), receivedAt: UsageFakes.start)
        XCTAssertEqual(signIn.accessToken, "a")
        XCTAssertEqual(signIn.refreshToken, "r")
        XCTAssertEqual(signIn.accessExpiresAt, UsageFakes.start.addingTimeInterval(28_800))
        XCTAssertEqual(signIn.expiresAt, UsageFakes.start.addingTimeInterval(2_400_000))
        XCTAssertEqual(signIn.account, UsageFakes.account)
        XCTAssertEqual(signIn.account.key, "11111111-2222-3333-4444-555555555555:66666666-7777-8888-9999-000000000000")
    }

    func testARenewalAnswerWithoutAccountOrRefreshTokenKeepsThePreviousOnes() throws {
        let previous = UsageFakes.signIn("a1", "r1")
        let renewed = try ClaudeTokenAnswer.signIn(from: UsageFakes.tokenAnswer(access: "a2", refresh: nil, withAccount: false), receivedAt: UsageFakes.start, previous: previous)
        XCTAssertEqual(renewed.accessToken, "a2")
        XCTAssertEqual(renewed.refreshToken, "r1")
        XCTAssertEqual(renewed.account, UsageFakes.account)
    }

    func testATokenAnswerWithoutAccessTokenOrAccountIsRefused() {
        XCTAssertThrowsError(try ClaudeTokenAnswer.signIn(from: Data(#"{"error": "invalid_grant"}"#.utf8), receivedAt: UsageFakes.start))
        XCTAssertThrowsError(try ClaudeTokenAnswer.signIn(from: UsageFakes.tokenAnswer(access: "a", refresh: "r", withAccount: false), receivedAt: UsageFakes.start))
    }

    func testTheSignInEndsAtItsDeadlineAndItsAccessIsRenewedFiveMinutesBefore() {
        let signIn = UsageFakes.signIn("a", "r", accessLeft: 600, deadline: 3600)
        XCTAssertFalse(signIn.isAccessDue(at: UsageFakes.start))
        XCTAssertTrue(signIn.isAccessDue(at: UsageFakes.start.addingTimeInterval(301)))
        XCTAssertFalse(signIn.hasEnded(at: UsageFakes.start.addingTimeInterval(3599)))
        XCTAssertTrue(signIn.hasEnded(at: UsageFakes.start.addingTimeInterval(3600)))
    }
}
