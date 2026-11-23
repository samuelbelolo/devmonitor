import Foundation

/// The limits of one account at the time it was read.
public struct AccountUsage: Sendable, Equatable {
    public let limits: [AccountLimit]
    /// The free resets the account has; nil when the read did not ask for them, so the ones read before still hold.
    public let resetCredits: [ResetCredit]?

    public init(limits: [AccountLimit], resetCredits: [ResetCredit]? = nil) {
        self.limits = limits
        self.resetCredits = resetCredits
    }

    /// Returns the same limits with these resets.
    /// @example usage.with(resetCredits: previous.resetCredits).resetCredits?.count // 2
    public func with(resetCredits credits: [ResetCredit]?) -> AccountUsage {
        AccountUsage(limits: limits, resetCredits: credits)
    }

    /// Returns how many resets show beside a gauge; a nil kind for the ones shown on the account's line.
    /// @example usage.resetsLeft(on: .weekOnModel("Fable")) // 3
    public func resetsLeft(on kind: AccountLimit.Kind?) -> Int {
        (resetCredits ?? []).filter { $0.shownOn == kind }.reduce(0) { $0 + $1.left }
    }

    /// Returns the grant spent by the reset shown beside a gauge: the provider's next one when it shows there.
    /// @example usage.nextCredit(on: .week)?.id // "g1"
    public func nextCredit(on kind: AccountLimit.Kind?) -> ResetCredit? {
        (resetCredits ?? []).first { $0.shownOn == kind && $0.left > 0 }
    }

    /// The limit closest to its cap; nil when the provider gave none.
    /// @example usage.fullest?.kind // .weekOnModel("Fable")
    public var fullest: AccountLimit? {
        limits.max { $0.percentUsed < $1.percentUsed }
    }

    /// What is left of the fullest limit, from 0 to 100: an account has only as much room as its tightest limit
    /// leaves. Nil when no limit is known.
    /// @example usage.room // 38
    public var room: Double? {
        fullest.map { 100 - $0.percentUsed }
    }
}
