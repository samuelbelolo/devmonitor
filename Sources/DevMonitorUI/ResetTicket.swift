import SwiftUI

/// The ticket beside a gauge: how many resets the account can spend on it. A click asks before using one.
struct ResetTicket: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: "ticket").font(.system(size: 10, weight: .semibold))
                Text("\(count)").font(.system(size: 11, weight: .semibold)).monospacedDigit()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6).padding(.vertical, 1.5)
            .background(Color.primary.opacity(0.06), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.18)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help(ResetStrings.ticketHelp(count))
    }
}
