import DevMonitorCore
import Foundation

extension UsageStore {
    /// Reads an account's resets again when its owner opens the confirmation, so the share and the count it shows are
    /// current; does nothing in a sample store.
    /// @example store.prepareSpend(of: account)
    func prepareSpend(of account: TrackedAccount) {
        spendOutcomes[account.id] = nil
        Task { await read(account.id, withResets: true) }
    }

    /// Spends, on its owner's confirmed click, the reset shown beside a gauge (nil for the account's line), then reads
    /// the account again whatever the answer. One spend at a time per account, one request id per click; does nothing
    /// in a sample store.
    /// @example store.spendReset(on: .weekOnModel("Fable"), of: account)
    func spendReset(on kind: AccountLimit.Kind?, of account: TrackedAccount) {
        guard let reader, !spending.contains(account.id),
              let credit = reading(of: account).usage?.nextCredit(on: kind) else { return }
        spending.insert(account.id)
        let requestID = UUID().uuidString
        Task {
            let outcome = await reader.spend(credit, of: account.id, requestID: requestID)
            spendOutcomes[account.id] = outcome
            await read(account.id, withResets: true)
            spending.remove(account.id)
        }
    }

    /// Hides the message of an account's last spend.
    /// @example store.dismissSpendOutcome(of: account)
    func dismissSpendOutcome(of account: TrackedAccount) {
        spendOutcomes[account.id] = nil
    }
}
