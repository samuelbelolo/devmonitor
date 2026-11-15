import Foundation

/// A free reset the provider grants an account, which its owner spends when they choose: spending one starts some of
/// the account's limits again at once. Not to be confused with a limit starting again on its own date
/// (`AccountLimit.resetsAt`, « reset dans » in the French window).
public struct ResetCredit: Sendable, Equatable {
    /// The provider's id of the grant, sent to spend it; nil when the provider picks which one it spends (Codex).
    public let id: String?
    /// How many resets of this grant are left.
    public let left: Int
    /// The limits it starts again; empty when it starts every limit of the account.
    public let clears: [AccountLimit.Kind]
    /// The gauge it shows beside: the broadest limit it starts again; nil when it starts a limit DevMonitor does not
    /// show, in which case it shows on the account's line.
    public let shownOn: AccountLimit.Kind?
    /// When the grant ends; nil when the provider does not say.
    public let endsAt: Date?

    /// Creates a grant of resets.
    /// @example ResetCredit(id: "g2", left: 1, clears: [.weekOnModel("Fable")], shownOn: .weekOnModel("Fable"), endsAt: nil).left // 1
    public init(id: String?, left: Int, clears: [AccountLimit.Kind], shownOn: AccountLimit.Kind?, endsAt: Date?) {
        self.id = id
        self.left = left
        self.clears = clears
        self.shownOn = shownOn
        self.endsAt = endsAt
    }
}

/// What spending a reset gave.
public enum ResetSpendOutcome: Sendable, Equatable {
    /// The provider says the reset was used.
    case spent
    /// Nothing needed starting again, so the provider kept the reset (Codex).
    case nothingToReset
    /// The provider has no reset left for the account.
    case noneLeft
    /// The provider said no, with the HTTP status and its words when it gave them; the reset was not used. The
    /// window shows both, so its owner can read back what the provider answered.
    case refused(status: Int?, reason: String?)
    /// No answer, or one DevMonitor cannot read: whether the reset was used is unknown until the account is read again.
    case unknown
    /// The sign-in has ended: only a new sign-in reads or spends anything on the account.
    case needsSignIn
}
