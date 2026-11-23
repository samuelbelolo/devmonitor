import Foundation

/// Signs in to an account: opens the provider's authorization page in the browser, waits on this Mac's loopback for
/// the browser to come back with a code, and exchanges that code for a sign-in. The sign-in is returned, not kept:
/// the caller shows the account it reads and keeps it once confirmed.
public enum SignInFlow {
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
        /// Every port the browser may come back to is taken, e.g. by a sign-in of the provider's own tool.
        case portTaken
    }

    /// Runs a sign-in with this method and returns it.
    /// @example try await SignInFlow.run(ClaudeSignInMethod(), open: { NSWorkspace.shared.open($0) }, transport: URLSessionTransport()).account.email // "dev@example.com"
    public static func run(_ method: SignInMethod, open: @Sendable (URL) -> Void, transport: HTTPTransport, now: @Sendable () -> Date = Date.init, timeout: TimeInterval = 300) async throws -> SignIn {
        let listener = try await listen(method)
        defer { listener.stop() }
        let pkce = PKCE.make()
        let state = PKCE.randomText()
        let redirectURI = method.redirectURI(port: listener.port)
        open(method.authorize(redirectURI: redirectURI, challenge: pkce.challenge, state: state))
        let query = try await listener.waitForCallback(timeout: timeout)
        guard query["state"] == state, let returned = query["code"], !returned.isEmpty else { throw Failure.stateMismatch }
        // The code can carry its state after a "#": the provider wants that one back.
        let parts = returned.split(separator: "#", maxSplits: 1).map(String.init)
        let request = method.exchange(code: parts[0], state: parts.count > 1 ? parts[1] : state, verifier: pkce.verifier, redirectURI: redirectURI)
        guard let answer = try? await transport.send(request) else { throw Failure.unreachable }
        guard answer.status == 200 else { throw Failure.refused(answer.status) }
        guard let signIn = try? method.signIn(from: answer.body, receivedAt: now()) else { throw Failure.unreadableAnswer }
        return signIn
    }

    /// Returns a listener started on the first free port the method allows.
    /// @example try await listen(ClaudeSignInMethod()).port // 54321
    private static func listen(_ method: SignInMethod) async throws -> CallbackListener {
        for port in method.ports.isEmpty ? [nil] : method.ports.map(Optional.some) {
            guard let listener = try? CallbackListener(port: port, path: method.callbackPath) else { continue }
            do {
                try await listener.start()
                return listener
            } catch {
                listener.stop()
            }
        }
        throw Failure.portTaken
    }
}
