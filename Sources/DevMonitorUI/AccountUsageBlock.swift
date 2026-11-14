import DevMonitorCore
import SwiftUI

/// One followed account: its name, one gauge per limit, and how fresh the reading is or what stops it.
struct AccountUsageBlock: View {
    /// How long before its end the sign-in is announced, with the button that renews it.
    private static let endWarning: TimeInterval = 3 * 86_400

    let account: TrackedAccount
    @EnvironmentObject private var usage: UsageStore
    @State private var isRenaming = false
    @State private var draft = ""

    var body: some View {
        let reading = usage.reading(of: account)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if isRenaming {
                    TextField(account.account.email, text: $draft).textFieldStyle(.roundedBorder)
                        .onSubmit { finishRenaming() }
                        .onExitCommand { isRenaming = false }
                } else {
                    Text(account.title).font(.system(size: 13.5, weight: .semibold)).lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 6)
                menu
            }
            if let limits = reading.usage?.limits, !limits.isEmpty {
                ForEach(Array(limits.enumerated()), id: \.offset) { _, limit in
                    LimitGaugeRow(limit: limit, isStale: reading.problem != nil)
                }
            } else if reading.problem == nil {
                Text(UsageStrings.notReadYet).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            footer(reading)
        }
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private var menu: some View {
        Menu {
            Button(UsageStrings.rename) {
                draft = account.name ?? ""
                isRenaming = true
            }
            Button(UsageStrings.signInAgain) { usage.startSignIn() }
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
                Button(UsageStrings.signInAgain) { usage.startSignIn() }
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

    private var tint: Color {
        if limit.percentUsed >= RoomCount.fullAt { return Palette.orphan }
        return limit.percentUsed >= 80 ? Palette.idle : Palette.ok
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(UsageStrings.name(of: limit.kind)).fontWeight(.medium)
                Spacer(minLength: 6)
                if let resetsAt = limit.resetsAt { Text(UsageStrings.resets(resetsAt)).font(.system(size: 11)).foregroundStyle(.secondary) }
                Text("\(Int(limit.percentUsed.rounded())) %").monospacedDigit().fontWeight(.semibold).frame(minWidth: 40, alignment: .trailing)
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
