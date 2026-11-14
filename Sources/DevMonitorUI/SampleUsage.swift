import DevMonitorCore
import Foundation
import SwiftUI

/// Made-up Claude accounts for reviewing the accounts window: one with room, one almost full, one whose sign-in ended.
/// Nothing here is read from the Mac that renders it.
@MainActor
public enum SampleUsage {
    /// Returns the accounts window filled with the sample accounts, with a sign-in to confirm when `confirming` is set.
    /// @example SampleUsage.window() // "2/3 Claude accounts with room"
    public static func window(confirming: Bool = false) -> some View {
        UsageContentView().environmentObject(store(confirming: confirming))
    }

    /// Returns the menu bar item of the accounts, with the sample accounts.
    /// @example SampleUsage.menuBar() // Claude's logo, then "2/3"
    public static func menuBar() -> some View {
        HStack(spacing: 5) { UsageMenuBarLabel() }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .environmentObject(store())
    }

    /// Returns the end of the agents window while no account is followed, its entry opened.
    /// @example SampleUsage.openEntry() // "Claude", what following an account does, the button
    public static func openEntry() -> some View {
        VStack(alignment: .leading, spacing: 10) { UsageEntry(isOpen: true) }
            .font(.system(size: 12.5))
            .padding(14)
            .frame(width: 360)
            .environmentObject(UsageStore.placeholder())
    }

    /// Returns a store that shows the sample accounts and never reads anything; with `confirming`, a new account waits
    /// for confirmation.
    /// @example SampleUsage.store().roomCount // (withRoom: 2, total: 3)
    static func store(confirming: Bool = false) -> UsageStore {
        let now = Date()
        let friday = now.addingTimeInterval(5 * 86_400)
        let codex = AccountID(provider: .codex, account: "sample-codex", organization: "", email: "dev@example.com")
        let accounts = [
            account("personal@example.com", name: "Personal", endsIn: 20),
            account("work@example.com", name: nil, endsIn: 25),
            account("team@example.com", name: "Team", endsIn: 9),
            TrackedAccount(account: codex, name: "Personal", signInEndsAt: nil),
            account("clients@example.com", name: nil, endsIn: 25),
            account("labs@example.com", name: nil, endsIn: 25),
        ]
        let fableReset = ResetCredit(id: "sample-fable", left: 1, clears: [.weekOnModel("Fable")], shownOn: .weekOnModel("Fable"), endsAt: now.addingTimeInterval(115 * 86_400))
        let codexResets = ResetCredit(id: nil, left: 3, clears: [], shownOn: .week, endsAt: nil)
        let readings = [
            accounts[0].id: AccountReading(usage: usage([(.week, 15), (.weekOnModel("Fable"), 17)], resetsAt: friday, credits: [fableReset]), readAt: now.addingTimeInterval(-180), problem: nil),
            accounts[1].id: AccountReading(usage: usage([(.week, 82), (.weekOnModel("Fable"), 96)], resetsAt: friday), readAt: now.addingTimeInterval(-240), problem: nil),
            accounts[2].id: AccountReading(usage: usage([(.week, 40), (.weekOnModel("Fable"), 30)], resetsAt: friday), readAt: now.addingTimeInterval(-6 * 3600), problem: .needsSignIn),
            accounts[3].id: AccountReading(usage: usage([(.week, 55)], resetsAt: now.addingTimeInterval(4 * 86_400), credits: [codexResets]), readAt: now.addingTimeInterval(-120), problem: nil),
            accounts[4].id: AccountReading(usage: usage([(.week, 5), (.weekOnModel("Fable"), 2)], resetsAt: friday), readAt: now.addingTimeInterval(-60), problem: nil),
            accounts[5].id: AccountReading(usage: usage([(.week, 61), (.weekOnModel("Fable"), 44)], resetsAt: friday), readAt: now.addingTimeInterval(-60), problem: nil),
        ]
        let running = [accounts[0].id: 4, accounts[3].id: 1, accounts[4].id: 2]
        guard confirming else { return UsageStore(sample: accounts, readings: readings, runningSessions: running) }
        let newcomer = AccountID(account: "sample-new", organization: "sample-org", email: "contact@example-studio.com")
        let signIn = SignIn(accessToken: "sample", refreshToken: "sample", accessExpiresAt: now, expiresAt: nil, account: newcomer)
        return UsageStore(sample: accounts, readings: readings, signInStep: .confirm(signIn, replaces: false))
    }

    /// Returns a sample account whose sign-in ends in this many days.
    /// @example account("dev@example.com", name: nil, endsIn: 20).title // "dev@example.com"
    private static func account(_ email: String, name: String?, endsIn days: Double) -> TrackedAccount {
        let id = AccountID(account: "sample-" + email, organization: "sample-org", email: email)
        return TrackedAccount(account: id, name: name, signInEndsAt: Date().addingTimeInterval(days * 86_400))
    }

    /// Returns usage with these limits, all starting again at the same date.
    /// @example usage([(.week, 15)], resetsAt: friday).room // 85
    private static func usage(_ limits: [(AccountLimit.Kind, Double)], resetsAt: Date, credits: [ResetCredit]? = nil) -> AccountUsage {
        AccountUsage(limits: limits.map { AccountLimit(kind: $0.0, percentUsed: $0.1, resetsAt: resetsAt) }, resetCredits: credits)
    }

    /// Returns the confirmation of a Fable reset, for the documentation: no calendar date in it, so the image is the
    /// same whatever day it is rendered.
    /// @example SampleUsage.resetConfirmation() // "Use a reset? Fable (64 %) starts again at once. …"
    public static func resetConfirmation() -> some View {
        let fable = ResetCredit(id: "sample-fable", left: 2, clears: [.weekOnModel("Fable")], shownOn: .weekOnModel("Fable"), endsAt: nil)
        let current = AccountUsage(limits: [AccountLimit(kind: .week, percentUsed: 58, resetsAt: nil), AccountLimit(kind: .weekOnModel("Fable"), percentUsed: 64, resetsAt: nil)], resetCredits: [fable])
        return ResetConfirmation(usage: current, kind: .weekOnModel("Fable"), cancel: {}, confirm: {})
            .padding(14)
            .frame(width: 360)
    }

    /// Returns the reset's panels for review: the confirmation of a Fable reset, then the notes of a spend.
    /// @example SampleUsage.resetPanels() // the confirmation, "Utilisation du reset…", then two outcomes
    public static func resetPanels() -> some View {
        let fable = ResetCredit(id: "sample-fable", left: 2, clears: [.weekOnModel("Fable")], shownOn: .weekOnModel("Fable"), endsAt: Date().addingTimeInterval(115 * 86_400))
        let week = ResetCredit(id: "sample-week", left: 1, clears: [.week, .weekOnModel("Fable")], shownOn: .week, endsAt: nil)
        let current = AccountUsage(limits: [AccountLimit(kind: .week, percentUsed: 35, resetsAt: nil), AccountLimit(kind: .weekOnModel("Fable"), percentUsed: 4, resetsAt: nil)], resetCredits: [fable, week])
        return VStack(alignment: .leading, spacing: 12) {
            ResetConfirmation(usage: current, kind: .weekOnModel("Fable"), cancel: {}, confirm: {})
            ResetConfirmation(usage: current, kind: .week, cancel: {}, confirm: {})
            ResetOutcomeNote(outcome: nil) {}
            ResetOutcomeNote(outcome: .spent) {}
            ResetOutcomeNote(outcome: .nothingToReset) {}
        }
        .padding(14)
        .frame(width: 330)
    }
}
