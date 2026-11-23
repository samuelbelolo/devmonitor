import Foundation

/// The permission DevMonitor holds to read the usage of one account: a pair of tokens and their deadlines.
public struct SignIn: Codable, Sendable, Equatable {
    /// How long before its end an access token is renewed, so that no read is sent with one about to expire.
    private static let renewalMargin: TimeInterval = 300

    public let accessToken: String
    public let refreshToken: String
    public let accessExpiresAt: Date
    /// When the sign-in itself ends: renewals do not move it, and past it only a new sign-in reads the account.
    /// Nil when the provider did not say.
    public let expiresAt: Date?
    public let account: AccountID
    /// When the provider asks for the access token to be renewed, ahead of its end; nil when it does not say.
    public let renewAfter: Date?

    public init(accessToken: String, refreshToken: String, accessExpiresAt: Date, expiresAt: Date?, account: AccountID, renewAfter: Date? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accessExpiresAt = accessExpiresAt
        self.expiresAt = expiresAt
        self.account = account
        self.renewAfter = renewAfter
    }

    /// Whether the access token is renewed before the next read: it ends within five minutes, or the provider's
    /// renewal date has come.
    /// @example signIn.isAccessDue(at: Date()) // false
    public func isAccessDue(at now: Date) -> Bool {
        if let renewAfter, renewAfter <= now { return true }
        return accessExpiresAt.timeIntervalSince(now) < Self.renewalMargin
    }

    /// Whether the sign-in has reached its deadline.
    /// @example signIn.hasEnded(at: Date()) // false
    public func hasEnded(at now: Date) -> Bool {
        expiresAt.map { $0 <= now } ?? false
    }
}
