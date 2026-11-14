import Foundation

/// Signing in to a Codex account the way the Codex client does: the browser comes back to 127.0.0.1 on port 1455,
/// or 1457 when 1455 is taken, the only ports OpenAI is known to accept for this client.
public struct CodexSignInMethod: SignInMethod {
    public init() {}

    public var ports: [UInt16] { [1455, 1457] }
    public var callbackPath: String { "/auth/callback" }

    public func redirectURI(port: UInt16) -> String {
        "http://127.0.0.1:\(port)/auth/callback"
    }

    public func authorize(redirectURI: String, challenge: String, state: String) -> URL {
        CodexEndpoints.authorize(redirectURI: redirectURI, challenge: challenge, state: state)
    }

    public func exchange(code: String, state: String, verifier: String, redirectURI: String) -> URLRequest {
        CodexEndpoints.exchange(code: code, verifier: verifier, redirectURI: redirectURI)
    }

    public func signIn(from body: Data, receivedAt: Date) throws -> SignIn {
        try CodexTokenAnswer.signIn(from: body, receivedAt: receivedAt)
    }
}
