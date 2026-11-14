import DevMonitorCore
import SwiftUI

/// The window opened from the accounts menu bar item: how many Claude accounts have room, then each account's limits.
public struct UsageContentView: View {
    @EnvironmentObject private var usage: UsageStore

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if usage.accounts.isEmpty {
                EmptyAccountsView()
            } else {
                header
                SignInStepView()
                ForEach(usage.sortedAccounts) { AccountUsageBlock(account: $0) }
            }
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
            Text("\(count.withRoom)/\(count.total)").font(.system(size: 32, weight: .bold)).monospacedDigit()
            Text(UsageStrings.withRoom).foregroundStyle(.secondary)
            Spacer()
            Button { usage.startSignIn() } label: { Image(systemName: "plus.circle") }
                .buttonStyle(.borderless)
                .help(UsageStrings.signInToAnAccount)
                .disabled(usage.signInStep == .waiting)
        }
    }
}

/// The window before any account is followed: what it is for, the button that signs in to a first account, and what
/// DevMonitor can see of it.
struct EmptyAccountsView: View {
    @EnvironmentObject private var usage: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                AgentLogoView(agent: .claude, size: 24)
                Text(UsageStrings.title).font(.system(size: 18, weight: .bold))
            }
            Text(UsageStrings.emptyPitch).fixedSize(horizontal: false, vertical: true)
            if usage.signInStep == .idle {
                // Drawn by hand: a prominent button turns grey whenever its window is not the key one, which a menu
                // bar window often is not.
                Button { usage.startSignIn() } label: {
                    Label(UsageStrings.signInFirst, systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AgentBrand.claudeOrange, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                SignInStepView()
            }
            Text(UsageStrings.emptyFinePrint).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
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
            panel { ConfirmSignInView(signIn: signIn, replaces: replaces, name: usage.suggestedName(for: signIn)) }
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

/// The account a sign-in obtained, with a name already offered for it, to add or drop.
struct ConfirmSignInView: View {
    let signIn: SignIn
    let replaces: Bool
    @EnvironmentObject private var usage: UsageStore
    @State private var name: String

    init(signIn: SignIn, replaces: Bool, name: String) {
        self.signIn = signIn
        self.replaces = replaces
        _name = State(initialValue: name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(UsageStrings.signedIn(signIn.account.email)).fontWeight(.semibold).lineLimit(1).truncationMode(.middle)
            if replaces { Text(UsageStrings.replacesFollowed).font(.system(size: 11)).foregroundStyle(.secondary) }
            HStack(spacing: 8) {
                Text(UsageStrings.name).foregroundStyle(.secondary)
                TextField(signIn.account.email, text: $name).textFieldStyle(.roundedBorder).onSubmit { usage.confirmSignIn(name: name) }
            }
            HStack {
                Button(UsageStrings.add) { usage.confirmSignIn(name: name) }.keyboardShortcut(.defaultAction)
                Button(UsageStrings.cancel) { usage.cancelSignIn() }
            }
        }
    }
}

/// The last line of the agents window while no Claude account is followed: it opens, in place, what following one
/// does and the button that signs in to the first.
struct UsageEntry: View {
    @EnvironmentObject private var usage: UsageStore
    @State private var isOpen: Bool

    init(isOpen: Bool = false) {
        _isOpen = State(initialValue: isOpen)
    }

    var body: some View {
        if !usage.hasAccounts {
            Divider()
            if isOpen || usage.signInStep != .idle {
                EmptyAccountsView().padding(.horizontal, 6)
            } else {
                HStack(spacing: 7) {
                    AgentLogoView(agent: .claude, size: 13)
                    Text(UsageStrings.trackQuotas).font(.system(size: 13.5, weight: .semibold))
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .contentShape(Rectangle())
                .onTapGesture { isOpen = true }
            }
        }
    }
}
