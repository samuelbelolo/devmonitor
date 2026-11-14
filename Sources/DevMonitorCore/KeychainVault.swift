import Foundation

/// Keeps the sign-ins in the login keychain through `/usr/bin/security`, the way Claude Code keeps its own.
///
/// The app cannot keep them itself: an item it adds is refused to the next build, whose code differs, even when both
/// are signed with the same certificate. An item `security` adds is read by `security`, whatever program asks.
/// The secret goes through the standard input of `security -i`, never through its arguments, which any program of
/// the Mac can list. It is the sign-in as JSON, in base64, so the line holds no space or quote.
public struct KeychainVault: SignInVault {
    /// Runs `security` with these arguments and this standard input; nil when it could not start or did not end.
    public typealias Run = @Sendable (_ arguments: [String], _ input: String?) -> CommandResult?

    /// The status `security` ends with when the item is not there.
    private static let notFound: Int32 = 44
    private let servicePrefix: String
    private let run: Run

    /// Creates a vault whose items are named after this prefix and their provider; `run` replaces the real
    /// `security` in the tests.
    /// @example KeychainVault() // Claude's sign-ins under local.devmonitor.claude, Codex's under local.devmonitor.codex
    public init(servicePrefix: String = "local.devmonitor", run: Run? = nil) {
        self.servicePrefix = servicePrefix
        self.run = run ?? { CommandRunner.result("/usr/bin/security", $0, input: $1, timeout: 10) }
    }

    /// Returns the service name of an account's item: the prefix and the account's provider.
    /// @example service(for: "codex:abc:") // "local.devmonitor.codex"
    private func service(for key: String) -> String {
        "\(servicePrefix).\(AccountID.provider(ofKey: key).rawValue)"
    }

    /// Writes the sign-in, then reads it back: a save that does not read back the same is refused.
    /// @example try vault.save(signIn)
    public func save(_ signIn: SignIn) throws {
        let secret = try Self.encoded(signIn)
        let line = "add-generic-password -U -s \(service(for: signIn.account.key)) -a \(signIn.account.key) -w \(secret)\n"
        guard run(["-i"], line)?.status == 0, try stored(signIn.account.key) == secret else { throw SignInVaultError.notSaved }
    }

    /// Reads the sign-in of an account.
    /// @example try vault.signIn(for: id.key)?.accessExpiresAt // 2026-11-15 00:24:54 +0000
    public func signIn(for key: String) throws -> SignIn? {
        guard let secret = try stored(key) else { return nil }
        guard let data = Data(base64Encoded: secret) else { throw SignInVaultError.unreadable }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(SignIn.self, from: data)
        } catch {
            throw SignInVaultError.unreadable
        }
    }

    /// Deletes the item of an account.
    /// @example try vault.remove(key: id.key)
    public func remove(key: String) throws {
        let status = run(["delete-generic-password", "-s", service(for: key), "-a", key], nil)?.status
        guard status == 0 || status == Self.notFound else { throw SignInVaultError.notRemoved }
    }

    /// Returns the text kept for an account; nil when there is no item, throws when `security` failed or hung.
    /// @example try stored(id.key) // "eyJhY2Nlc3…"
    private func stored(_ key: String) throws -> String? {
        guard let result = run(["find-generic-password", "-s", service(for: key), "-a", key, "-w"], nil) else { throw SignInVaultError.unreadable }
        if result.status == Self.notFound { return nil }
        guard result.status == 0 else { throw SignInVaultError.unreadable }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns a sign-in as sorted JSON in base64, the same text for the same sign-in.
    /// @example try encoded(signIn) // "eyJhY2Nlc3…"
    private static func encoded(_ signIn: SignIn) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(signIn).base64EncodedString()
    }
}
