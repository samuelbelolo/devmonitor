import Foundation

/// How one provider signs an account in: where the browser comes back, the authorization page, the code exchange,
/// and how to read the tokens it answers.
public protocol SignInMethod: Sendable {
    /// The ports the browser may come back to, tried in order; empty for any free port.
    var ports: [UInt16] { get }
    /// The path the browser comes back on.
    var callbackPath: String { get }
    /// Returns the address the browser comes back to on this port.
    /// @example method.redirectURI(port: 1455) // "http://127.0.0.1:1455/auth/callback"
    func redirectURI(port: UInt16) -> String
    /// Returns the authorization page.
    /// @example method.authorize(redirectURI: uri, challenge: "c", state: "s").host // "claude.ai"
    func authorize(redirectURI: String, challenge: String, state: String) -> URL
    /// Returns the request that turns the code the browser brought back into tokens.
    /// @example method.exchange(code: "k", state: "s", verifier: "v", redirectURI: uri).httpMethod // "POST"
    func exchange(code: String, state: String, verifier: String, redirectURI: String) -> URLRequest
    /// Returns the sign-in the exchange answered.
    /// @example try method.signIn(from: body, receivedAt: Date()).account.email // "dev@example.com"
    func signIn(from body: Data, receivedAt: Date) throws -> SignIn
}
