import DevMonitorCore
import SwiftUI

/// The confirmation shown inside an account's block before a reset is spent: what starts again with its share now,
/// what will be left, when the reset expires, and the two buttons. Inside the block, so the bubble stays open.
struct ResetConfirmation: View {
    /// A share under which a reset gives back too little to spend without a word.
    private static let littleUsed: Double = 10

    let usage: AccountUsage
    /// The gauge whose ticket was clicked; nil for the account's line.
    let kind: AccountLimit.Kind?
    let cancel: () -> Void
    let confirm: () -> Void

    var body: some View {
        let credit = usage.nextCredit(on: kind)
        let cleared = credit.map(clearedLimits) ?? []
        VStack(alignment: .leading, spacing: 5) {
            Text(ResetStrings.confirmTitle).font(.system(size: 12.5, weight: .semibold))
            if let credit {
                Text(ResetStrings.clears(cleared, everything: credit.clears.isEmpty))
                Text(ResetStrings.left(after: usage.resetsLeft(on: kind) - 1)).foregroundStyle(.secondary)
                if let ends = credit.endsAt { Text(ResetStrings.endsOn(ends)).foregroundStyle(.secondary) }
                if !cleared.isEmpty, cleared.allSatisfy({ $0.percentUsed < Self.littleUsed }) {
                    Text(ResetStrings.littleUsed).foregroundStyle(LimitTint.color(percentUsed: 85) ?? .orange)
                }
            }
            HStack {
                Spacer()
                Button(ResetStrings.cancel, action: cancel)
                // Drawn by hand: a prominent button turns grey whenever a menu bar window is not the key one.
                Button(action: confirm) {
                    Text(ResetStrings.confirm).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 3.5)
                        .background(Color.orange, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(credit == nil)
                .opacity(credit == nil ? 0.4 : 1)
            }
            .padding(.top, 2)
        }
        .font(.system(size: 11.5))
        .fixedSize(horizontal: false, vertical: true)
        .padding(8)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Returns the account's limits a reset starts again, every one when it names none; a limit it names that the
    /// account does not show is left out.
    /// @example clearedLimits(fableCredit).map(\.kind) // [.weekOnModel("Fable")]
    private func clearedLimits(_ credit: ResetCredit) -> [AccountLimit] {
        credit.clears.isEmpty ? usage.limits : usage.limits.filter { credit.clears.contains($0.kind) }
    }
}

/// What the last spend on an account gave, or that one is being spent, with a button to hide it.
struct ResetOutcomeNote: View {
    /// Nil while the reset is being spent.
    let outcome: ResetSpendOutcome?
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let outcome {
                Text(ResetStrings.outcome(outcome)).foregroundStyle(outcome == .spent ? Color.primary : Color.secondary)
                Spacer(minLength: 6)
                Button(ResetStrings.dismiss, action: dismiss).controlSize(.small)
            } else {
                ProgressView().controlSize(.small)
                Text(ResetStrings.spending).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .font(.system(size: 11.5))
        .fixedSize(horizontal: false, vertical: true)
    }
}
