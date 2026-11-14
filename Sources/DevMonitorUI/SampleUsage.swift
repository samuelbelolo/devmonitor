import DevMonitorCore
import Foundation
import SwiftUI

/// Made-up Claude accounts for reviewing the accounts window: one with room, one almost full, one whose sign-in ended.
/// Nothing here is read from the Mac that renders it.
@MainActor
public enum SampleUsage {
    /// Returns the accounts window filled with the sample accounts.
    /// @example SampleUsage.window() // "2/3 Claude accounts with room"
    public static func window() -> some View {
        UsageContentView().environmentObject(store())
    }

    /// Returns a store that shows the sample accounts and never reads anything.
    /// @example SampleUsage.store().roomCount // (withRoom: 1, total: 3)
    static func store() -> UsageStore {
        let now = Date()
        let friday = now.addingTimeInterval(5 * 86_400)
        let accounts = [
            account("personal@example.com", name: "Perso", endsIn: 20),
            account("work@example.com", name: nil, endsIn: 2),
            account("team@example.com", name: "Team", endsIn: 9),
        ]
        let readings = [
            accounts[0].id: AccountReading(usage: usage([(.week, 15), (.weekOnModel("Fable"), 17)], resetsAt: friday), readAt: now.addingTimeInterval(-180), problem: nil),
            accounts[1].id: AccountReading(usage: usage([(.week, 82), (.weekOnModel("Fable"), 96)], resetsAt: friday), readAt: now.addingTimeInterval(-240), problem: nil),
            accounts[2].id: AccountReading(usage: usage([(.week, 40), (.weekOnModel("Fable"), 30)], resetsAt: friday), readAt: now.addingTimeInterval(-6 * 3600), problem: .needsSignIn),
        ]
        return UsageStore(sample: accounts, readings: readings)
    }

    /// Returns a sample account whose sign-in ends in this many days.
    /// @example account("dev@example.com", name: nil, endsIn: 20).title // "dev@example.com"
    private static func account(_ email: String, name: String?, endsIn days: Double) -> TrackedAccount {
        let id = ClaudeAccountID(account: "sample-" + email, organization: "sample-org", email: email)
        return TrackedAccount(account: id, name: name, signInEndsAt: Date().addingTimeInterval(days * 86_400))
    }

    /// Returns usage with these limits, all starting again at the same date.
    /// @example usage([(.week, 15)], resetsAt: friday).room // 85
    private static func usage(_ limits: [(AccountLimit.Kind, Double)], resetsAt: Date) -> AccountUsage {
        AccountUsage(limits: limits.map { AccountLimit(kind: $0.0, percentUsed: $0.1, resetsAt: resetsAt) })
    }
}
