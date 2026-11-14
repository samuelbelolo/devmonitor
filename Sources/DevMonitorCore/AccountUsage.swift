import Foundation

/// The limits of one account at the time it was read.
public struct AccountUsage: Sendable, Equatable {
    public let limits: [AccountLimit]

    public init(limits: [AccountLimit]) {
        self.limits = limits
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
