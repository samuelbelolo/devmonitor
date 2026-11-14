import Foundation

/// Signs in to a Claude account: opens the authorization page in the browser, waits on this Mac's loopback for the
/// browser to come back with a code, and exchanges that code for a sign-in. The sign-in is returned, not kept: the
/// caller shows the account it reads and keeps it once confirmed.
public enum ClaudeSignInFlow {
    public enum Failure: Error, Equatable {
        /// The browser did not come back in time.
        case noAnswer
        /// The browser came back with another state than the one sent: the answer is not this sign-in's.
        case stateMismatch
        /// The provider refused the code, with this status.
        case refused(Int)
        /// The provider could not be reached.
        case unreachable
        /// The provider answered something that is not a sign-in.
        case unreadableAnswer
    }

    /// Runs a sign-in and returns it.
    /// @example try await ClaudeSignInFlow.run(open: { NSWorkspace.shared.open($0) }, transport: URLSessionTransport()).account.email // "dev@example.com"
    public static func run(open: @Sendable (URL) -> Void, transport: HTTPTransport, now: @Sendable () -> Date = Date.init, timeout: TimeInterval = 300) async throws -> SignIn {
        let listener = try CallbackListener()
        try await listener.start()
        defer { listener.stop() }
        let pkce = PKCE.make()
        let state = PKCE.randomText()
        let redirectURI = "http://localhost:\(listener.port)/callback"
        open(ClaudeEndpoints.authorize(redirectURI: redirectURI, challenge: pkce.challenge, state: state))
        let query = try await listener.waitForCallback(timeout: timeout)
        guard query["state"] == state, let returned = query["code"], !returned.isEmpty else { throw Failure.stateMismatch }
        // The code can carry its state after a "#": the provider wants that one back.
        let parts = returned.split(separator: "#", maxSplits: 1).map(String.init)
        let request = ClaudeEndpoints.exchange(code: parts[0], state: parts.count > 1 ? parts[1] : state, verifier: pkce.verifier, redirectURI: redirectURI)
        guard let answer = try? await transport.send(request) else { throw Failure.unreachable }
        guard answer.status == 200 else { throw Failure.refused(answer.status) }
        guard let signIn = try? ClaudeTokenAnswer.signIn(from: answer.body, receivedAt: now()) else { throw Failure.unreadableAnswer }
        return signIn
    }
}
