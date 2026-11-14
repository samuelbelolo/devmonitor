import CryptoKit
import Foundation

/// The secret a sign-in starts with and the challenge sent in its place (RFC 7636): only who holds the verifier can
/// turn the code the browser brings back into tokens.
public struct PKCE: Sendable, Equatable {
    public let verifier: String
    public let challenge: String

    /// Returns a new random verifier and its challenge.
    /// @example PKCE.make().verifier.count // 43
    public static func make() -> PKCE {
        let verifier = randomText()
        return PKCE(verifier: verifier, challenge: challenge(for: verifier))
    }

    /// Returns the S256 challenge of a verifier: its SHA-256, in base64url without padding.
    /// @example PKCE.challenge(for: "dBjftJeZ4CVP-mJ92K1qqh8V3JK6-yHlnTOp1qBfBHA") // "bU69_A-JQYKr9sWEgXSMqYHToy0G1baYIqxmsXRLoks"
    public static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    /// Returns 32 random bytes in base64url without padding, 43 characters.
    /// @example PKCE.randomText().count // 43
    public static func randomText() -> String {
        base64URL(Data(SymmetricKey(size: .bits256).withUnsafeBytes { Array($0) }))
    }

    /// Returns bytes in base64url without padding.
    /// @example base64URL(Data([0xfb, 0xff])) // "-_8"
    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
