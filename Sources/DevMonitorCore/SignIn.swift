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
    public let account: ClaudeAccountID

    public init(accessToken: String, refreshToken: String, accessExpiresAt: Date, expiresAt: Date?, account: ClaudeAccountID) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accessExpiresAt = accessExpiresAt
        self.expiresAt = expiresAt
        self.account = account
    }

    /// Whether the access token ends within five minutes, so it is renewed before the next read.
    /// @example signIn.isAccessDue(at: Date()) // false
    public func isAccessDue(at now: Date) -> Bool {
        accessExpiresAt.timeIntervalSince(now) < Self.renewalMargin
    }

    /// Whether the sign-in has reached its deadline.
    /// @example signIn.hasEnded(at: Date()) // false
    public func hasEnded(at now: Date) -> Bool {
        expiresAt.map { $0 <= now } ?? false
    }
}
