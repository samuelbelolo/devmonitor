import DevMonitorCore
import SwiftUI

/// The window opened from the accounts menu bar item: how many Claude accounts have room, then every account's
/// limits, Claude's then Codex's, in one grid.
public struct UsageContentView: View {
    @EnvironmentObject private var usage: UsageStore

    public init() {}

    /// From three accounts on, they sit in two columns.
    private var columns: Int { usage.accounts.count >= 3 ? 2 : 1 }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if usage.accounts.isEmpty {
                EmptyAccountsView()
            } else {
                header
                SignInStepView()
                // One grid for every account: each block's logo tells Claude from Codex.
                AccountGrid(accounts: usage.sortedAccounts, columns: columns)
            }
        }
        // Laid out at the height it asks the window for, so the margin under the last row is the same as the others.
        .fixedSize(horizontal: false, vertical: true)
        .font(.system(size: 12.5))
        .padding(14)
        .frame(width: columns == 2 ? 710 : 360)
        .background(WindowFit())
        .onAppear { usage.windowOpened() }
    }

    /// The Claude count when a Claude account is followed, else Codex's name; then the + menu.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            let count = usage.roomCount
            if count.total > 0 {
                Text("\(count.withRoom)/\(count.total)").font(.system(size: 32, weight: .bold)).monospacedDigit()
                Text(UsageStrings.withRoom).foregroundStyle(.secondary)
            } else {
                AgentLogoView(agent: .codex, size: 18)
                Text(UsageStrings.name(of: .codex)).font(.system(size: 18, weight: .bold))
            }
            Spacer()
            RefreshButton()
            Menu {
                ForEach(Provider.allCases, id: \.self) { provider in
                    Button(UsageStrings.signIn(to: provider)) { usage.startSignIn(provider) }
                }
            } label: {
                Image(systemName: "plus.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(UsageStrings.signInToAnAccount)
            .disabled(usage.signInStep == .waiting)
        }
    }
}

/// The button that reads every account again now; its arrow turns, a turn a second, while the reads run.
struct RefreshButton: View {
    @EnvironmentObject private var usage: UsageStore

    var body: some View {
        Button { usage.refreshNow() } label: {
            TimelineView(.animation(paused: !usage.isRefreshing)) { context in
                let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
                Image(systemName: "arrow.clockwise.circle").rotationEffect(.degrees(usage.isRefreshing ? turn * 360 : 0))
            }
            .contentShape(Rectangle())
        }
        // Plain, in the text color: a borderless button turns grey whenever a menu bar window is not the key one, and
        // it sits beside the + menu, which does not.
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .help(UsageStrings.readNow)
        .disabled(usage.isRefreshing)
    }
}

/// One provider's accounts, row by row in the given number of columns; the blocks of a row share its height.
struct AccountGrid: View {
    let accounts: [TrackedAccount]
    let columns: Int

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(Array(stride(from: 0, to: accounts.count, by: columns)), id: \.self) { start in
                GridRow {
                    ForEach(accounts[start..<min(start + columns, accounts.count)]) { account in
                        AccountUsageBlock(account: account, fillsHeight: columns > 1)
                    }
                    // A row left short keeps its block in the first column, at the same width as the others.
                    if accounts.count - start < columns { Color.clear.gridCellUnsizedAxes([.vertical]) }
                }
            }
        }
    }
}

/// The window before any account is followed: what it is for, one line per provider with the button that signs in
/// to its first account, and what DevMonitor does with the access.
struct EmptyAccountsView: View {
    @EnvironmentObject private var usage: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                AgentLogoView(agent: .claude, size: 20)
                AgentLogoView(agent: .codex, size: 20)
                Text(UsageStrings.quotas).font(.system(size: 18, weight: .bold))
            }
            Text(UsageStrings.emptyPitch).fixedSize(horizontal: false, vertical: true)
            if usage.signInStep == .idle {
                ForEach(Provider.allCases, id: \.self) { provider in
                    HStack(spacing: 9) {
                        AgentLogoView(agent: provider.agent, size: 17)
                        Text(UsageStrings.name(of: provider)).font(.system(size: 14, weight: .semibold))
                        Spacer(minLength: 6)
                        connectButton(provider)
                    }
                    .padding(9)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
                }
            } else {
                SignInStepView()
            }
            Text(UsageStrings.emptyFinePrint).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    /// Returns the button that signs in to a provider's first account, in the colours of its logo's tile. Drawn by
    /// hand: a prominent button turns grey whenever its window is not the key one, which a menu bar window often is not.
    /// @example connectButton(.claude) // "Connecter" on Claude's orange
    private func connectButton(_ provider: Provider) -> some View {
        let tile = AgentBrand.tile(provider.agent)
        return Button { usage.startSignIn(provider) } label: {
            Text(UsageStrings.connect)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(tile.logo)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(tile.background, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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
            panel { ConfirmSignInView(signIn: signIn, replaces: replaces, name: usage.currentName(for: signIn)) }
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

/// The last line of the agents window while no account is followed: it opens, in place, what following one does and
/// a button per provider that signs in to the first.
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
                HStack(spacing: 6) {
                    AgentLogoView(agent: .claude, size: 13)
                    AgentLogoView(agent: .codex, size: 13)
                    Text(UsageStrings.quotasEntry).font(.system(size: 13.5, weight: .semibold)).padding(.leading, 2)
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
