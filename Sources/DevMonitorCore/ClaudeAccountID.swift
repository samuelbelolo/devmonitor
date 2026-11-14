import Foundation

/// Which Claude account a sign-in reads: an account within an organisation, and the email it signs in with.
public struct ClaudeAccountID: Codable, Sendable, Hashable {
    public let account: String
    public let organization: String
    public let email: String

    public init(account: String, organization: String, email: String) {
        self.account = account
        self.organization = organization
        self.email = email
    }

    /// The account and its organisation together: one email in two organisations is two accounts, each with its
    /// own limits. It names the keychain item, so it holds no space.
    /// @example id.key // "1111…:6666…"
    public var key: String { "\(account):\(organization)" }
}
