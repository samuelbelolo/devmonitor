import AppKit
import DevMonitorCore
import Foundation

/// The Claude and Codex accounts the accounts window follows, their last reading, and the sign-in under way.
///
/// The app's own store is the only one that touches the keychain and the network: a renewal ends the pair in use, so
/// a second program reading the same accounts would sign the app out. The sample store, for the documentation's
/// images and the tests, never reads anything.
@MainActor
public final class UsageStore: ObservableObject {
    /// Where the sign-in started from the window stands.
    enum SignInStep: Equatable {
        case idle
        case waiting
        case confirm(SignIn, replaces: Bool)
        case failed(String)
    }

    /// Every account is read every ten minutes, each after a random delay of up to half a minute.
    private static let period: TimeInterval = 600
    private static let spread: ClosedRange<Double> = 0...30

    @Published private(set) var accounts: [TrackedAccount]
    @Published private(set) var readings: [String: AccountReading]
    @Published private(set) var signInStep: SignInStep = .idle
    /// Whether the accounts are being read again because the ↻ button was pressed.
    @Published private(set) var isRefreshing = false
    /// How many running agent sessions draw on each account, by account key; absent when none.
    @Published private(set) var runningSessions: [String: Int] = [:]
    /// The key of the Claude account a new session would sign in with; nil when Claude Code is signed out.
    @Published private(set) var defaultAccount: String?
    /// The accounts on which a reset is being spent.
    @Published var spending: Set<String> = []
    /// What the last spend on each account gave, shown until its owner dismisses it.
    @Published var spendOutcomes: [String: ResetSpendOutcome] = [:]
    /// Reads and spends on the accounts; nil in a sample store, which reads and spends nothing.
    let reader: UsageReader?
    private let defaults: UserDefaults?
    private var loop: Task<Void, Never>?
    private var signInTask: Task<Void, Never>?
    /// Moves on every 30 s so the menu bar's wait until a Claude account is free counts down between two reads.
    @Published private(set) var clock = Date()
    private var clockTask: Task<Void, Never>?

    /// Creates the app's store: reads the followed accounts now, then every ten minutes.
    /// @example UsageStore() // reading the accounts kept in the keychain
    public init() {
        defaults = .standard
        accounts = TrackedAccount.load(from: .standard)
        readings = [:]
        reader = UsageReader(vault: KeychainVault(), transport: URLSessionTransport())
        loop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            while !Task.isCancelled {
                await self?.readAll(spread: true)
                try? await Task.sleep(for: .seconds(Self.period))
            }
        }
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                self?.clock = Date()
            }
        }
    }

    /// Creates a store that shows these accounts and readings and never reads, signs in or saves anything.
    /// @example UsageStore(sample: accounts, readings: readings).hasAccounts // true
    init(sample accounts: [TrackedAccount], readings: [String: AccountReading], signInStep: SignInStep = .idle,
         runningSessions: [String: Int] = [:], defaultAccount: String? = nil) {
        self.accounts = accounts
        self.readings = readings
        self.signInStep = signInStep
        self.runningSessions = runningSessions
        self.defaultAccount = defaultAccount
        reader = nil
        defaults = nil
    }

    /// Counts the running sessions on each account from the account each session draws on, by session id.
    /// @example store.noteSessions(["4242-1": "acc:org", "4243-1": "acc:org"]); store.runningSessions // ["acc:org": 2]
    public func noteSessions(_ sessionAccounts: [String: String]) {
        let counts = sessionAccounts.values.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        if counts != runningSessions { runningSessions = counts }
    }

    /// Keeps the key of the Claude account a new session would sign in with.
    /// @example store.noteDefaultAccount("acc:org"); store.defaultAccount // "acc:org"
    public func noteDefaultAccount(_ key: String?) {
        if key != defaultAccount { defaultAccount = key }
    }

    /// Returns a store that follows no account and never reads anything, for a window rendered outside the app.
    /// @example UsageStore.placeholder().hasAccounts // false
    public static func placeholder() -> UsageStore {
        UsageStore(sample: [], readings: [:])
    }

    /// Whether an account is followed: until one is, the accounts item stays out of the menu bar and the agents
    /// window offers to follow one.
    public var hasAccounts: Bool { !accounts.isEmpty }

    /// Returns the name already given to the account a sign-in reads; empty for a new account, which is then called
    /// by its whole email until its owner names it.
    /// @example store.currentName(for: signIn) // ""
    func currentName(for signIn: SignIn) -> String {
        accounts.first { $0.id == signIn.account.key }?.name ?? ""
    }

    /// The accounts, Claude's then Codex's, each provider's with the most room first and those never read last.
    var sortedAccounts: [TrackedAccount] {
        Provider.allCases.flatMap(sortedAccounts(of:))
    }

    /// Returns one provider's accounts, the most room first; those never read last.
    /// @example store.sortedAccounts(of: .codex).count // 1
    func sortedAccounts(of provider: Provider) -> [TrackedAccount] {
        accounts.enumerated().filter { $0.element.account.provider == provider }.sorted { lhs, rhs in
            let left = reading(of: lhs.element).usage?.room ?? -1
            let right = reading(of: rhs.element).usage?.room ?? -1
            return left == right ? lhs.offset < rhs.offset : left > right
        }.map(\.element)
    }

    /// The share used of the fullest limit of the Claude account most running sessions draw on, or of the one a new
    /// session would use when none runs: the menu bar's Claude figure. Nil when neither is followed or it was never
    /// read.
    var busiestClaudePercent: Double? {
        let claude = accounts.filter { $0.account.provider == .claude }
        let percents = claude.reduce(into: [String: Double]()) { $0[$1.id] = reading(of: $1).usage?.fullest?.percentUsed }
        let key = BusiestAccount.key(among: claude.map(\.id), sessions: runningSessions, percentUsed: percents,
                                     fallback: defaultAccount)
        return key.flatMap { percents[$0] }
    }

    /// When every Claude account followed is full, the soonest moment one of them is usable again; nil otherwise.
    var claudeFreeAgainAt: Date? {
        NextFreeAccount.date(of: accounts.filter { $0.account.provider == .claude }.map { reading(of: $0).usage })
    }

    /// Whether an account of this provider is followed.
    /// @example store.follows(.codex) // true
    func follows(_ provider: Provider) -> Bool {
        accounts.contains { $0.account.provider == provider }
    }

    /// The share used of the fullest limit among the Codex accounts read; nil when none is followed or read.
    var codexFullest: Double? {
        accounts.filter { $0.account.provider == .codex }.compactMap { reading(of: $0).usage?.fullest?.percentUsed }.max()
    }

    /// Returns how a provider's accounts sign in.
    /// @example UsageStore.signInMethod(for: .codex).ports // [1455, 1457]
    static func signInMethod(for provider: Provider) -> SignInMethod {
        switch provider {
        case .claude: ClaudeSignInMethod()
        case .codex: CodexSignInMethod()
        }
    }

    /// Returns what is known of an account.
    /// @example store.reading(of: account).usage?.room // 83
    func reading(of account: TrackedAccount) -> AccountReading {
        readings[account.id] ?? .empty
    }

    /// Reads, when the window opens, the accounts whose usage or resets were not read for two minutes; these reads ask
    /// for the resets, which the timer's reads never do.
    /// @example store.windowOpened()
    func windowOpened() {
        Task {
            let now = Date()
            for account in accounts where reading(of: account).isDue(at: now) || reading(of: account).areCreditsDue(at: now) {
                await read(account.id, withResets: true)
            }
        }
    }

    /// Opens the provider's authorization page and waits for the browser; the account obtained is shown for
    /// confirmation.
    /// @example store.startSignIn(.codex)
    func startSignIn(_ provider: Provider) {
        guard reader != nil, signInStep != .waiting else { return }
        signInStep = .waiting
        // The window closes when the browser comes forward; it opens again with the account to confirm.
        weak var origin = MenuBarButton.open()
        signInTask = Task { [weak self] in
            do {
                let signIn = try await SignInFlow.run(Self.signInMethod(for: provider), open: { url in DispatchQueue.main.async { NSWorkspace.shared.open(url) } }, transport: URLSessionTransport())
                guard !Task.isCancelled, let self else { return }
                self.signInStep = .confirm(signIn, replaces: self.accounts.contains { $0.id == signIn.account.key })
            } catch {
                guard !Task.isCancelled else { return }
                self?.signInStep = .failed(UsageStrings.failure(error, provider: provider))
            }
            if let origin { MenuBarButton.reopen(origin) }
        }
    }

    /// Drops the sign-in under way, or the message of the last one.
    /// @example store.cancelSignIn()
    func cancelSignIn() {
        signInTask?.cancel()
        signInTask = nil
        signInStep = .idle
    }

    /// Keeps the sign-in shown for confirmation, follows its account under the name given, and reads it. An empty
    /// name calls the account by its email.
    /// @example store.confirmSignIn(name: "Miramo")
    func confirmSignIn(name: String) {
        guard case .confirm(let signIn, _) = signInStep, let reader else { return }
        Task {
            do {
                try await reader.keep(signIn)
            } catch {
                signInStep = .failed(UsageStrings.notKept)
                return
            }
            let given = name.trimmingCharacters(in: .whitespaces)
            accounts = TrackedAccount.adding(signIn.account, name: given, signInEndsAt: signIn.expiresAt, to: accounts)
            persist()
            signInStep = .idle
            await read(signIn.account.key, withResets: true)
        }
    }

    /// Gives an account a name of its own; an empty name brings back its email.
    /// @example store.rename(account, to: "Perso")
    func rename(_ account: TrackedAccount, to name: String) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index].name = name.trimmingCharacters(in: .whitespaces)
        persist()
    }

    /// Stops following an account and forgets its sign-in.
    /// @example store.remove(account)
    func remove(_ account: TrackedAccount) {
        accounts.removeAll { $0.id == account.id }
        readings[account.id] = nil
        persist()
        guard let reader else { return }
        Task { try? await reader.forget(account.id) }
    }

    /// Reads every account now, all at once, and says so for at least half a second, so the ↻ button visibly turns.
    /// Does nothing in a sample store.
    /// @example store.refreshNow()
    func refreshNow() {
        guard reader != nil, !isRefreshing else { return }
        isRefreshing = true
        let keys = accounts.map(\.id)
        Task {
            let started = Date()
            await withTaskGroup(of: Void.self) { group in
                for key in keys { group.addTask { await self.read(key, withResets: true) } }
            }
            let shown = Date().timeIntervalSince(started)
            if shown < 0.6 { try? await Task.sleep(for: .seconds(0.6 - shown)) }
            isRefreshing = false
        }
    }

    /// Reads every account, one after the other, each after a random delay when `spread` is set.
    /// @example await store.readAll(spread: true)
    func readAll(spread: Bool) async {
        for account in accounts {
            if spread { try? await Task.sleep(for: .seconds(Double.random(in: Self.spread))) }
            await read(account.id)
        }
    }

    /// Reads one account, and its resets when `withResets` is set, and takes in the outcome; does nothing in a sample
    /// store.
    /// @example await store.read(account.id, withResets: true)
    func read(_ key: String, withResets: Bool = false) async {
        guard let reader else { return }
        let outcome = await reader.read(key, withResets: withResets)
        guard accounts.contains(where: { $0.id == key }) else { return }
        var reading = readings[key] ?? .empty
        reading.apply(outcome, at: Date())
        readings[key] = reading
    }

    /// Keeps the followed accounts for the next launch.
    /// @example persist()
    private func persist() {
        if let defaults { TrackedAccount.save(accounts, to: defaults) }
    }
}
