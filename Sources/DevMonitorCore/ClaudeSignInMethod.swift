import Foundation

/// Signing in to a Claude account: any free port of the loopback, asking to read the profile only.
public struct ClaudeSignInMethod: SignInMethod {
    public init() {}

    public var ports: [UInt16] { [] }
    public var callbackPath: String { "/callback" }

    public func redirectURI(port: UInt16) -> String {
        "http://localhost:\(port)/callback"
    }

    public func authorize(redirectURI: String, challenge: String, state: String) -> URL {
        ClaudeEndpoints.authorize(redirectURI: redirectURI, challenge: challenge, state: state)
    }

    public func exchange(code: String, state: String, verifier: String, redirectURI: String) -> URLRequest {
        ClaudeEndpoints.exchange(code: code, state: state, verifier: verifier, redirectURI: redirectURI)
    }

    public func signIn(from body: Data, receivedAt: Date) throws -> SignIn {
        try ClaudeTokenAnswer.signIn(from: body, receivedAt: receivedAt)
    }
}
