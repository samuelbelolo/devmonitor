import DevMonitorCore
import SwiftUI

/// The window opened from the accounts menu bar item: how many Claude accounts have room, then each account's limits.
public struct UsageContentView: View {
    @EnvironmentObject private var usage: UsageStore

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            SignInStepView()
            if usage.accounts.isEmpty && usage.signInStep == .idle {
                Text(UsageStrings.noAccount).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).padding(.vertical, 6)
            }
            ForEach(usage.sortedAccounts) { AccountUsageBlock(account: $0) }
        }
        .font(.system(size: 12.5))
        .padding(14)
        .frame(width: 360)
        .background(WindowFit())
        .onAppear { usage.windowOpened() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            let count = usage.roomCount
            Text(count.total == 0 ? "–" : "\(count.withRoom)/\(count.total)").font(.system(size: 32, weight: .bold)).monospacedDigit()
            Text(UsageStrings.withRoom).foregroundStyle(.secondary)
            Spacer()
            Button { usage.startSignIn() } label: { Image(systemName: "plus.circle") }
                .buttonStyle(.borderless)
                .help(UsageStrings.signInToAnAccount)
                .disabled(usage.signInStep == .waiting)
        }
    }
}

/// The sign-in under way: waiting for the browser, the account obtained to confirm, or why it failed.
struct SignInStepView: View {
    @EnvironmentObject private var usage: UsageStore

    var body: some View {
        switch usage.signInStep {
        case .idle:
            EmptyView()
        case .waiting:
            panel {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(UsageStrings.waitingForBrowser)
                    Spacer(minLength: 6)
                    Button(UsageStrings.cancel) { usage.cancelSignIn() }
                }
            }
        case .confirm(let signIn, let replaces):
            panel {
                VStack(alignment: .leading, spacing: 6) {
                    Text(UsageStrings.signedIn(signIn.account.email)).fontWeight(.semibold)
                    if replaces { Text(UsageStrings.replacesFollowed).font(.system(size: 11)).foregroundStyle(.secondary) }
                    HStack {
                        Button(UsageStrings.add) { usage.confirmSignIn() }.keyboardShortcut(.defaultAction)
                        Button(UsageStrings.cancel) { usage.cancelSignIn() }
                    }
                }
            }
        case .failed(let message):
            panel {
                HStack(spacing: 8) {
                    Text(message).foregroundStyle(Palette.orphan).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 6)
                    Button(UsageStrings.close) { usage.cancelSignIn() }
                }
            }
        }
    }

    /// Frames a step like an account block.
    /// @example panel { Text("…") }
    private func panel(@ViewBuilder _ content: () -> some View) -> some View {
        content().padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}
