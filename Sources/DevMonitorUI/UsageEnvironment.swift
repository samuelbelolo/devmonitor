import SwiftUI

extension View {
    /// Gives the accounts window its store, and keeps the count of running sessions on each account and the account
    /// a new session would use up to date from the scan; the scan publishes before it changes, so each is taken from
    /// the value it sends.
    /// @example UsageContentView().usageEnvironment(usage: usage, sessionsFrom: store)
    public func usageEnvironment(usage: UsageStore, sessionsFrom store: MonitorStore) -> some View {
        environmentObject(usage)
            .onReceive(store.$sessionAccounts) { usage.noteSessions($0) }
            .onReceive(store.$defaultClaudeAccount) { usage.noteDefaultAccount($0) }
    }
}
