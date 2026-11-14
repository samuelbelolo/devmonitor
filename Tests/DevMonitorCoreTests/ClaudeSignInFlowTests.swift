import DevMonitorCore
import XCTest

final class ClaudeSignInFlowTests: XCTestCase {
    /// Plays the browser: reads the authorization page's address and comes back to the app with a code.
    /// @example browser(state: nil)(url) // calls the callback with the page's own state
    private func browser(code: String = "the-code", state: String? = nil, seen: SeenPage) -> @Sendable (URL) -> Void {
        { url in
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
            seen.record(query)
            var back = URLComponents(string: query["redirect_uri"] ?? "")!
            back.queryItems = [URLQueryItem(name: "code", value: code), URLQueryItem(name: "state", value: state ?? query["state"])]
            Task { _ = try? await URLSession.shared.data(from: back.url!) }
        }
    }

    /// What the authorization page was opened with.
    final class SeenPage: @unchecked Sendable {
        private let lock = NSLock()
        private var query: [String: String] = [:]

        /// Keeps the query of the page.
        /// @example seen.record(["state": "s"])
        func record(_ query: [String: String]) {
            lock.lock()
            self.query = query
            lock.unlock()
        }

        var page: [String: String] {
            lock.lock()
            defer { lock.unlock() }
            return query
        }
    }

    func testASignInComesBackFromTheBrowserAndIsExchangedWithTheVerifier() async throws {
        let seen = SeenPage()
        let provider = FakeProvider(signIn: [.answer(200, UsageFakes.tokenAnswer(access: "a1", refresh: "r1"))])
        let signIn = try await ClaudeSignInFlow.run(open: browser(seen: seen), transport: provider, now: { UsageFakes.start }, timeout: 10)
        XCTAssertEqual(signIn.accessToken, "a1")
        XCTAssertEqual(signIn.account.email, "dev@example.com")
        let exchanges = await provider.sent("signIn")
        let exchange = try XCTUnwrap(exchanges.first)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: exchange.httpBody ?? Data()) as? [String: String])
        XCTAssertEqual(body["code"], "the-code")
        XCTAssertEqual(body["redirect_uri"], seen.page["redirect_uri"])
        XCTAssertEqual(PKCE.challenge(for: body["code_verifier"] ?? ""), seen.page["code_challenge"])
        XCTAssertTrue(seen.page["redirect_uri"]?.hasPrefix("http://localhost:") == true)
    }

    func testACodeCarryingItsStateAfterAHashIsSplit() async throws {
        let seen = SeenPage()
        let provider = FakeProvider(signIn: [.answer(200, UsageFakes.tokenAnswer(access: "a1", refresh: "r1"))])
        _ = try await ClaudeSignInFlow.run(open: browser(code: "the-code#the-state", seen: seen), transport: provider, now: { UsageFakes.start }, timeout: 10)
        let exchanges = await provider.sent("signIn")
        let exchange = try XCTUnwrap(exchanges.first)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: exchange.httpBody ?? Data()) as? [String: String])
        XCTAssertEqual(body["code"], "the-code")
        XCTAssertEqual(body["state"], "the-state")
    }

    func testABrowserComingBackWithAnotherStateIsRefusedWithoutAnyExchange() async {
        let provider = FakeProvider(signIn: [.answer(200, UsageFakes.tokenAnswer(access: "a1", refresh: "r1"))])
        do {
            _ = try await ClaudeSignInFlow.run(open: browser(state: "forged", seen: SeenPage()), transport: provider, now: { UsageFakes.start }, timeout: 10)
            XCTFail("accepted a forged state")
        } catch {
            XCTAssertEqual(error as? ClaudeSignInFlow.Failure, .stateMismatch)
        }
        let sent = await provider.sent
        XCTAssertTrue(sent.isEmpty)
    }

    func testABrowserThatNeverComesBackEndsTheWait() async {
        do {
            _ = try await ClaudeSignInFlow.run(open: { _ in }, transport: FakeProvider(), now: { UsageFakes.start }, timeout: 0.5)
            XCTFail("waited for ever")
        } catch {
            XCTAssertEqual(error as? ClaudeSignInFlow.Failure, .noAnswer)
        }
    }

    func testARefusedExchangeIsReported() async {
        let provider = FakeProvider(signIn: [.answer(400, Data(#"{"error": "invalid_grant"}"#.utf8))])
        do {
            _ = try await ClaudeSignInFlow.run(open: browser(seen: SeenPage()), transport: provider, now: { UsageFakes.start }, timeout: 10)
            XCTFail("accepted a refused exchange")
        } catch {
            XCTAssertEqual(error as? ClaudeSignInFlow.Failure, .refused(400))
        }
    }
}
