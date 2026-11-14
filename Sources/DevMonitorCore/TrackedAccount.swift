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

    /// Mail providers whose addresses name a person, not an organisation.
    private static let mailProviders: Set<String> = [
        "gmail.com", "googlemail.com", "icloud.com", "me.com", "mac.com", "outlook.com", "outlook.fr", "hotmail.com",
        "hotmail.fr", "live.com", "live.fr", "msn.com", "yahoo.com", "yahoo.fr", "proton.me", "protonmail.com", "pm.me",
        "free.fr", "orange.fr", "wanadoo.fr", "sfr.fr", "laposte.net", "gmx.com", "gmx.fr", "aol.com", "fastmail.com",
    ]

    /// Returns the list with this account added at the end, or put in place of the one it signs in to again, at its
    /// place. A name given replaces the one it had; no name keeps it.
    /// @example TrackedAccount.adding(id, name: "Perso", signInEndsAt: deadline, to: accounts).count // 3
    public static func adding(_ account: ClaudeAccountID, name: String? = nil, signInEndsAt: Date?, to accounts: [TrackedAccount]) -> [TrackedAccount] {
        guard let index = accounts.firstIndex(where: { $0.id == account.key }) else {
            return accounts + [TrackedAccount(account: account, name: name, signInEndsAt: signInEndsAt)]
        }
        var updated = accounts
        updated[index] = TrackedAccount(account: account, name: name ?? accounts[index].name, signInEndsAt: signInEndsAt)
        return updated
    }

    /// Returns a name to offer for the account of an email: its organisation's domain, or the person on a mail
    /// provider; empty when the text is not an email.
    /// @example TrackedAccount.suggestedName(for: "contact@miramo.fr") // "Miramo"
    public static func suggestedName(for email: String) -> String {
        let parts = email.lowercased().split(separator: "@")
        guard parts.count == 2 else { return "" }
        let local = String(parts[0]), domain = String(parts[1])
        if mailProviders.contains(domain) {
            return words(local.split(separator: "+").first.map(String.init) ?? local)
        }
        var labels = domain.split(separator: ".").map(String.init).dropLast()
        // A second-level suffix such as "co" in example.co.uk is not the organisation.
        if labels.count > 1, let last = labels.last, last.count <= 3 { labels = labels.dropLast() }
        return words(labels.last ?? "")
    }

    /// Returns a part of an email as capitalised words.
    /// @example words("client-a") // "Client A"
    private static func words(_ text: String) -> String {
        text.split(whereSeparator: { ".-_".contains($0) }).map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
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
