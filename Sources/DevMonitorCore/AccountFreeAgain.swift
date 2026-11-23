import Foundation

/// When a full account can be used again.
public enum AccountFreeAgain {
    /// Returns the moment this account is usable again: the latest reset among its limits at `AccountLimit.fullAt` or
    /// above. Nil when it was never read, when none of its limits is full, when a full one has no known reset date, or
    /// when that moment is not after `now`: the reading is then older than the reset.
    /// @example AccountFreeAgain.date(of: fullUntilTwoAndFive, after: oneOClock) // five o'clock
    public static func date(of usage: AccountUsage?, after now: Date) -> Date? {
        let full = usage?.limits.filter { $0.percentUsed >= AccountLimit.fullAt } ?? []
        let resets = full.compactMap(\.resetsAt)
        guard !full.isEmpty, resets.count == full.count else { return nil }
        return resets.max().flatMap { $0 > now ? $0 : nil }
    }
}
