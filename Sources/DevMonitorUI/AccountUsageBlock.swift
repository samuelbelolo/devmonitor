import DevMonitorCore
import SwiftUI

/// One followed account: its name, one gauge per limit, and how fresh the reading is or what stops it.
struct AccountUsageBlock: View {
    /// How long before its end the sign-in is announced, with the button that renews it.
    private static let endWarning: TimeInterval = 3 * 86_400

    let account: TrackedAccount
    /// Takes the height it is given, to match the other block of its row.
    var fillsHeight = false
    @EnvironmentObject private var usage: UsageStore
    @State private var isRenaming = false
    @State private var draft = ""
    /// Whether the confirmation of a reset is open, and for which gauge (nil for the account's line).
    @State private var isConfirming = false
    @State private var confirmingKind: AccountLimit.Kind?

    var body: some View {
        let reading = usage.reading(of: account)
        let sharedReset = Self.sharedReset(of: reading.usage?.limits ?? [])
        let sessions = isRenaming ? nil : usage.runningSessions[account.id]
        VStack(alignment: .leading, spacing: 8) {
            nameRow(reading, sharedReset: sharedReset, sessions: sessions)
            if let current = reading.usage, !current.limits.isEmpty {
                ForEach(Array(current.limits.enumerated()), id: \.offset) { _, limit in
                    LimitGaugeRow(limit: limit, isStale: reading.problem != nil, showsReset: sharedReset == nil,
                                  resetsLeft: canSpend(reading) ? current.resetsLeft(on: limit.kind) : 0,
                                  onTicket: { openConfirmation(on: limit.kind) })
                }
            } else if reading.problem == nil {
                Text(UsageStrings.notReadYet).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            resetPanel(reading)
            footer(reading)
        }
        .padding(10)
        // In a grid, every block of a row takes the row's height, so the backgrounds line up.
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    /// Returns the account's first line: its logo, its name or the field that renames it, the blue dot and count of
    /// the sessions running on it when given, then when its limits start again and its menu.
    /// @example nameRow(reading, sharedReset: friday, sessions: 4) // ✳ Perso ● 4   repart dans 4 j 23 h  ⋯
    private func nameRow(_ reading: AccountReading, sharedReset: Date?, sessions: Int?) -> some View {
        HStack(spacing: 6) {
            AgentLogoView(agent: account.account.provider.agent, size: 13)
            if isRenaming {
                TextField(account.account.email, text: $draft).textFieldStyle(.roundedBorder)
                    .onSubmit { finishRenaming() }
                    .onExitCommand { isRenaming = false }
            } else {
                Text(account.title).font(.system(size: 13.5, weight: .semibold)).lineLimit(1).truncationMode(.middle)
                if let sessions { InUseDot(sessions: sessions) }
            }
            Spacer(minLength: 6)
            if canSpend(reading), let left = reading.usage?.resetsLeft(on: nil), left > 0 {
                ResetTicket(count: left) { openConfirmation(on: nil) }
            }
            if let sharedReset { ResetCountdown(date: sharedReset).opacity(reading.problem == nil ? 1 : 0.45) }
            menu
        }
    }

    /// Returns the confirmation of a reset while it is open, then the spend in progress or what it gave.
    /// @example resetPanel(reading) // "Utiliser un reset ? …  [Annuler] [Utiliser le reset]"
    @ViewBuilder private func resetPanel(_ reading: AccountReading) -> some View {
        if usage.spending.contains(account.id) {
            ResetOutcomeNote(outcome: nil) {}
        } else if let outcome = usage.spendOutcomes[account.id] {
            ResetOutcomeNote(outcome: outcome) { usage.dismissSpendOutcome(of: account) }
        } else if isConfirming, let current = reading.usage {
            ResetConfirmation(usage: current, kind: confirmingKind, cancel: { isConfirming = false }) {
                isConfirming = false
                usage.spendReset(on: confirmingKind, of: account)
            }
        }
    }

    /// Whether the account's resets can be offered: not while its sign-in has ended, nor while one is being spent.
    /// @example canSpend(reading) // true
    private func canSpend(_ reading: AccountReading) -> Bool {
        reading.problem != .needsSignIn && !usage.spending.contains(account.id)
    }

    /// Opens the confirmation for the reset shown beside a gauge, reading the account's resets again meanwhile.
    /// @example openConfirmation(on: .weekOnModel("Fable"))
    private func openConfirmation(on kind: AccountLimit.Kind?) {
        confirmingKind = kind
        isConfirming = true
        usage.prepareSpend(of: account)
    }

    private var menu: some View {
        Menu {
            Button(UsageStrings.rename) {
                draft = account.name ?? ""
                isRenaming = true
            }
            Button(UsageStrings.signInAgain) { usage.startSignIn(account.account.provider) }
            Divider()
            Button(UsageStrings.remove, role: .destructive) { usage.remove(account) }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    /// The last line: the reading's age, what stopped the last read, and the end of the sign-in when it is near.
    @ViewBuilder private func footer(_ reading: AccountReading) -> some View {
        let endsSoon = account.signInEndsAt.map { $0.timeIntervalSinceNow < Self.endWarning } ?? false
        if reading.problem == .needsSignIn || endsSoon {
            HStack(spacing: 8) {
                Text(reading.problem == .needsSignIn ? UsageStrings.signInEnded : account.signInEndsAt.map(UsageStrings.signInEnds) ?? "")
                    .foregroundStyle(Palette.idle)
                Spacer(minLength: 6)
                Button(UsageStrings.signInAgain) { usage.startSignIn(account.account.provider) }
            }
            .font(.system(size: 11))
        }
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Text(status(reading, at: context.date)).font(.system(size: 11)).foregroundStyle(.tertiary)
        }
    }

    /// Returns the age of the reading, then why the last read gave nothing new, if it did not.
    /// @example status(reading, at: Date()) // "read 3 min ago · Could not read it right now."
    private func status(_ reading: AccountReading, at now: Date) -> String {
        let age = reading.readAt.map { UsageStrings.readAgo(DisplayFormat.duration(seconds: Int(now.timeIntervalSince($0)))) }
        let problem: String? = switch reading.problem {
        case .throttled(let until): UsageStrings.throttled(until: until)
        case .unreachable: UsageStrings.unreachable
        case .needsSignIn, nil: nil
        }
        return [age, problem].compactMap { $0 }.joined(separator: " · ")
    }

    /// Returns the moment every limit starts again, when they all start again within the same minute; nil when they
    /// do not, or when one does not say. The block then says it once, instead of on each gauge.
    /// @example sharedReset(of: [week, fable]) // the coming Friday at 05:00
    static func sharedReset(of limits: [AccountLimit]) -> Date? {
        let dates = limits.map(\.resetsAt)
        guard !dates.isEmpty, !dates.contains(nil), let first = dates.compactMap({ $0 }).min(), let last = dates.compactMap({ $0 }).max(),
              last.timeIntervalSince(first) <= 60 else { return nil }
        return first
    }

    /// Keeps the name typed and leaves the field.
    /// @example finishRenaming()
    private func finishRenaming() {
        usage.rename(account, to: draft)
        isRenaming = false
    }
}

/// One limit: its name, the share used as a bar that turns orange at 80 % and red at 95 %, and when it starts again.
struct LimitGaugeRow: View {
    let limit: AccountLimit
    /// Draws the limit pale, for a reading the last read could not renew.
    let isStale: Bool
    /// Says when this limit starts again; off when the block says it once for all its limits.
    var showsReset = true
    /// How many resets the account can spend on this limit; the ticket shows when there is one.
    var resetsLeft = 0
    /// What a click on the ticket does.
    var onTicket: () -> Void = {}

    /// Green while there is room; from 80 %, the strong orange that turns red by 95 %.
    private var tint: Color {
        LimitTint.color(percentUsed: limit.percentUsed) ?? Palette.ok
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(UsageStrings.name(of: limit.kind)).fontWeight(.medium)
                if resetsLeft > 0 { ResetTicket(count: resetsLeft, action: onTicket) }
                Spacer(minLength: 6)
                if showsReset, let resetsAt = limit.resetsAt { ResetCountdown(date: resetsAt) }
                Text(UsageStrings.used(Int(limit.percentUsed.rounded()))).monospacedDigit().fontWeight(.semibold).fixedSize()
                    .foregroundStyle(LimitTint.color(percentUsed: limit.percentUsed) ?? Color.primary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.1))
                    Capsule().fill(tint).frame(width: max(geometry.size.width * limit.percentUsed / 100, limit.percentUsed > 0 ? 4 : 0))
                }
            }
            .frame(height: 6)
        }
        .opacity(isStale ? 0.45 : 1)
    }
}

/// How long until a limit starts again, counted down while the window is open.
struct ResetCountdown: View {
    let date: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Text(UsageStrings.resetsIn(Int(date.timeIntervalSince(context.date)))).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
        }
    }
}
