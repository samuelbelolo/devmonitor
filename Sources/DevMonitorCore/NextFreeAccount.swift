import Foundation

/// When every followed account is full, the moment the first of them can be used again.
public enum NextFreeAccount {
    /// Returns the soonest date one of these accounts is usable again, nil unless every one was read and has a limit
    /// at `AccountLimit.fullAt` or above. An account is usable again once all its full limits have started again; one
    /// whose full limit has no known reset date is left out.
    /// @example NextFreeAccount.date(of: [fullUntilTwo, fullUntilFive]) // two o'clock
    public static func date(of usages: [AccountUsage?]) -> Date? {
        guard !usages.isEmpty else { return nil }
        var soonest: Date?
        for usage in usages {
            let full = usage?.limits.filter { $0.percentUsed >= AccountLimit.fullAt } ?? []
            guard !full.isEmpty else { return nil }
            let resets = full.compactMap(\.resetsAt)
            guard resets.count == full.count, let free = resets.max() else { continue }
            soonest = min(soonest ?? free, free)
        }
        return soonest
    }
}
