import Foundation

/// A cap the provider puts on an account over a period: the share of it already used, and when it starts again.
public struct AccountLimit: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// The week, every model together.
        case week
        /// The week on one model, such as Fable.
        case weekOnModel(String)
        /// The five hours Claude counts on top of the week.
        case fiveHours
        /// A cap DevMonitor does not know, by the name the provider gives it. It counts like the others: a cap the
        /// provider reports may be the one that stops the account.
        case other(String)
    }

    public let kind: Kind
    /// The share used, from 0 to 100.
    public let percentUsed: Double
    /// When the limit starts again; nil when the provider does not say.
    public let resetsAt: Date?

    /// Creates a limit, bringing a share given outside 0 to 100 back inside.
    /// @example AccountLimit(kind: .week, percentUsed: 104, resetsAt: nil).percentUsed // 100
    public init(kind: Kind, percentUsed: Double, resetsAt: Date?) {
        self.kind = kind
        self.percentUsed = min(max(percentUsed, 0), 100)
        self.resetsAt = resetsAt
    }
}
