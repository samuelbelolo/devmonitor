import Foundation

/// Which account a sign-in reads: a provider, an account within an organisation, and the email it signs in with.
public struct AccountID: Codable, Sendable, Hashable {
    public let provider: Provider
    public let account: String
    public let organization: String
    public let email: String

    public init(provider: Provider = .claude, account: String, organization: String, email: String) {
        self.provider = provider
        self.account = account
        self.organization = organization
        self.email = email
    }

    /// Reads an account kept before providers were named: it is a Claude account.
    /// @example try JSONDecoder().decode(AccountID.self, from: firstVersion).provider // .claude
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = try container.decodeIfPresent(Provider.self, forKey: .provider) ?? .claude
        account = try container.decode(String.self, forKey: .account)
        organization = try container.decode(String.self, forKey: .organization)
        email = try container.decode(String.self, forKey: .email)
    }

    /// The account and its organisation together: one email in two organisations is two accounts, each with its
    /// own limits. It names the keychain item, so it holds no space. A Claude key keeps the shape of the first
    /// version; the others start with their provider.
    /// @example id.key // "1111…:6666…"
    public var key: String {
        provider == .claude ? "\(account):\(organization)" : "\(provider.rawValue):\(account):\(organization)"
    }

    /// Returns the provider a key belongs to.
    /// @example AccountID.provider(ofKey: "codex:abc:") // .codex
    public static func provider(ofKey key: String) -> Provider {
        Provider.allCases.first { $0 != .claude && key.hasPrefix($0.rawValue + ":") } ?? .claude
    }
}
