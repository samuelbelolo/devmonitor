import Foundation

/// An account the window follows: which one, the name its owner gave it, and when its sign-in ends. Its tokens are
/// kept in the keychain, never here.
public struct TrackedAccount: Codable, Sendable, Equatable, Identifiable {
    private static let defaultsKey = "trackedClaudeAccounts"

    public let account: ClaudeAccountID
    public var name: String?
    public var signInEndsAt: Date?

    public init(account: ClaudeAccountID, name: String?, signInEndsAt: Date?) {
        self.account = account
        self.name = name
        self.signInEndsAt = signInEndsAt
    }

    public var id: String { account.key }

    /// The name its owner gave it, or else its email.
    /// @example TrackedAccount(account: id, name: nil, signInEndsAt: nil).title // "dev@example.com"
    public var title: String {
        let given = name?.trimmingCharacters(in: .whitespaces) ?? ""
        return given.isEmpty ? account.email : given
    }

    /// Returns the list with this account added at the end, or put in place of the one it signs in to again,
    /// keeping that one's name and place.
    /// @example TrackedAccount.adding(id, signInEndsAt: deadline, to: accounts).count // 3
    public static func adding(_ account: ClaudeAccountID, signInEndsAt: Date?, to accounts: [TrackedAccount]) -> [TrackedAccount] {
        guard let index = accounts.firstIndex(where: { $0.id == account.key }) else {
            return accounts + [TrackedAccount(account: account, name: nil, signInEndsAt: signInEndsAt)]
        }
        var updated = accounts
        updated[index] = TrackedAccount(account: account, name: accounts[index].name, signInEndsAt: signInEndsAt)
        return updated
    }

    /// Returns the accounts kept in these defaults; none when there are none or they cannot be read.
    /// @example TrackedAccount.load(from: .standard).count // 3
    public static func load(from defaults: UserDefaults) -> [TrackedAccount] {
        guard let data = defaults.data(forKey: defaultsKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([TrackedAccount].self, from: data)) ?? []
    }

    /// Keeps the accounts in these defaults.
    /// @example TrackedAccount.save(accounts, to: .standard)
    public static func save(_ accounts: [TrackedAccount], to defaults: UserDefaults) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try? encoder.encode(accounts), forKey: defaultsKey)
    }
}
