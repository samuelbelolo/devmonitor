import Foundation

/// What a read of an account gave.
public enum UsageReadOutcome: Sendable, Equatable {
    /// The account's limits.
    case read(AccountUsage)
    /// No sign-in, one past its deadline, or one the provider refused: only a new sign-in reads the account.
    case needsSignIn
    /// The provider asked to wait: no request is sent for this account before that date.
    case throttled(until: Date)
    /// No usable answer: the network, the server, the keychain, or an answer of another shape. Worth trying again.
    case unreachable
}

/// Reads the usage of the followed accounts, Claude's and Codex's, and renews their sign-ins.
///
/// A renewal answers a new pair of tokens and ends the access token in use at once, so the new pair is kept before
/// anything else: in the vault, and in memory when the vault refused it, to be saved again on the next read. The reads
/// and spends of one account run one after the other, so a refresh token is never spent twice.
public actor UsageReader {
    /// How long a refusal without a delay holds the next read of an account back.
    private static let defaultWait: TimeInterval = 600

    private let vault: SignInVault
    private let transport: HTTPTransport
    private let services: [Provider: UsageService]
    private let now: @Sendable () -> Date
    /// The latest pair of each account, which may be newer than the vault's.
    private var current: [String: SignIn] = [:]
    /// The accounts whose latest pair the vault refused.
    private var unsaved: Set<String> = []
    private var throttledUntil: [String: Date] = [:]
    /// The read of each account that runs or waits its turn, which a read asking for no more joins.
    private var running: [String: RunningRead] = [:]
    /// The last work queued on each account; the next one starts when it ends.
    private var queue: [String: Task<Void, Never>] = [:]

    /// A read in progress, and whether it asks for the resets.
    private struct RunningRead {
        let id: UUID
        let withResets: Bool
        let task: Task<UsageReadOutcome, Never>
    }

    /// Creates a reader of the accounts kept in this vault, through these services, one per provider.
    /// @example UsageReader(vault: KeychainVault(), transport: URLSessionTransport())
    public init(vault: SignInVault, transport: HTTPTransport, services: [Provider: UsageService] = [.claude: ClaudeService(), .codex: CodexService()], now: @escaping @Sendable () -> Date = Date.init) {
        self.vault = vault
        self.transport = transport
        self.services = services
        self.now = now
    }

    /// Reads an account, and its free resets when `withResets` is set. A read asked while another of the same account
    /// runs gets that one's outcome when it asks for no more; a read for resets asked during a plain read follows it.
    /// @example await reader.read(id.key, withResets: true) // .read(usage)
    public func read(_ key: String, withResets: Bool = false) async -> UsageReadOutcome {
        if let ongoing = running[key], ongoing.withResets || !withResets { return await ongoing.task.value }
        let id = UUID()
        let task = enqueue(key) { await self.perform(key, withResets: withResets) }
        running[key] = RunningRead(id: id, withResets: withResets, task: task)
        let outcome = await task.value
        if running[key]?.id == id { running[key] = nil }
        return outcome
    }

    /// Spends one reset of an account, after any read of it in progress. Sent once; sent again with the same
    /// `requestID` only after the provider refused the access token and it was renewed, which means the first one was
    /// not taken. No answer is never followed by another try: the outcome is then unknown until the account is read.
    /// @example await reader.spend(credit, of: id.key, requestID: UUID().uuidString) // .spent
    public func spend(_ credit: ResetCredit, of key: String, requestID: String) async -> ResetSpendOutcome {
        await enqueue(key) { await self.performSpend(credit, of: key, requestID: requestID) }.value
    }

    /// Queues work on an account after the work already queued on it, and returns its task.
    /// @example enqueue(id.key) { await self.perform(id.key, withResets: false) }
    private func enqueue<T: Sendable>(_ key: String, _ work: @escaping @Sendable () async -> T) -> Task<T, Never> {
        let previous = queue[key]
        let task = Task { () -> T in
            _ = await previous?.value
            return await work()
        }
        queue[key] = Task { _ = await task.value }
        return task
    }

    /// Keeps a new sign-in, in place of the one held for the same account.
    /// @example try await reader.keep(signIn)
    public func keep(_ signIn: SignIn) throws {
        try vault.save(signIn)
        let key = signIn.account.key
        current[key] = signIn
        unsaved.remove(key)
        throttledUntil[key] = nil
    }

    /// Forgets an account's sign-in, here and in the vault.
    /// @example try await reader.forget(id.key)
    public func forget(_ key: String) throws {
        try vault.remove(key: key)
        current[key] = nil
        unsaved.remove(key)
        throttledUntil[key] = nil
    }

    /// Reads an account: renews its access token when it is about to end or was refused, once.
    /// @example await perform(id.key, withResets: false) // .read(usage)
    private func perform(_ key: String, withResets: Bool) async -> UsageReadOutcome {
        if let until = throttledUntil[key], until > now() { return .throttled(until: until) }
        let held: SignIn?
        do { held = try current[key] ?? vault.signIn(for: key) } catch { return .unreachable }
        guard var signIn = held, !signIn.hasEnded(at: now()) else { return .needsSignIn }
        guard let service = services[signIn.account.provider] else { return .unreachable }
        if unsaved.contains(key) { keepRenewed(signIn) }
        var renewed = false
        if signIn.isAccessDue(at: now()) {
            switch await renew(signIn, with: service) {
            case .renewed(let fresh): signIn = fresh
            case .stopped(let outcome): return outcome
            }
            renewed = true
        }
        while true {
            guard let answer = try? await transport.send(service.usageRequest(for: signIn, withResets: withResets)) else { return .unreachable }
            switch answer.status {
            case 200:
                return (try? service.usage(from: answer.body)).map(UsageReadOutcome.read) ?? .unreachable
            case 401 where !renewed:
                switch await renew(signIn, with: service) {
                case .renewed(let fresh): signIn = fresh
                case .stopped(let outcome): return outcome
                }
                renewed = true
            case 401, 403:
                return .needsSignIn
            case 429:
                return throttle(key, answer)
            default:
                return .unreachable
            }
        }
    }

    /// Spends one reset: renews the access token first when it is about to end, and once more when it is refused.
    /// @example await performSpend(credit, of: id.key, requestID: "r") // .spent
    private func performSpend(_ credit: ResetCredit, of key: String, requestID: String) async -> ResetSpendOutcome {
        let held: SignIn?
        do { held = try current[key] ?? vault.signIn(for: key) } catch { return .unknown }
        guard var signIn = held, !signIn.hasEnded(at: now()) else { return .needsSignIn }
        guard let service = services[signIn.account.provider],
              service.spendRequest(credit, for: signIn, requestID: requestID) != nil else { return .refused(status: nil, reason: nil) }
        if unsaved.contains(key) { keepRenewed(signIn) }
        var renewed = false
        if signIn.isAccessDue(at: now()) {
            switch await renew(signIn, with: service) {
            case .renewed(let fresh): signIn = fresh
            case .stopped(let outcome): return outcome == .needsSignIn ? .needsSignIn : .unknown
            }
            renewed = true
        }
        while true {
            guard let request = service.spendRequest(credit, for: signIn, requestID: requestID),
                  let answer = try? await transport.send(request) else { return .unknown }
            // A second refusal after a renewal is this request's own, not the sign-in's: the read that follows tells.
            guard answer.status == 401, !renewed else { return service.spendOutcome(status: answer.status, body: answer.body) }
            switch await renew(signIn, with: service) {
            case .renewed(let fresh): signIn = fresh
            case .stopped(let outcome): return outcome == .needsSignIn ? .needsSignIn : .unknown
            }
            renewed = true
        }
    }

    /// What a renewal gave.
    private enum Renewal {
        case renewed(SignIn)
        case stopped(UsageReadOutcome)
    }

    /// Renews a sign-in and keeps the new pair; a refusal asks for a new sign-in.
    /// @example await renew(signIn, with: ClaudeService()) // .renewed(fresh)
    private func renew(_ signIn: SignIn, with service: UsageService) async -> Renewal {
        let key = signIn.account.key
        guard let answer = try? await transport.send(service.renewal(of: signIn)) else { return .stopped(.unreachable) }
        switch answer.status {
        case 200:
            guard let fresh = try? service.renewed(from: answer.body, receivedAt: now(), previous: signIn) else { return .stopped(.unreachable) }
            keepRenewed(fresh)
            return .renewed(fresh)
        case 400, 401, 403:
            return .stopped(.needsSignIn)
        case 429:
            return .stopped(throttle(key, answer))
        default:
            return .stopped(.unreachable)
        }
    }

    /// Keeps a renewed pair in memory, and in the vault when it takes it.
    /// @example keepRenewed(fresh)
    private func keepRenewed(_ signIn: SignIn) {
        let key = signIn.account.key
        current[key] = signIn
        do {
            try vault.save(signIn)
            unsaved.remove(key)
        } catch {
            unsaved.insert(key)
        }
    }

    /// Holds an account's reads back for the delay the provider gave, ten minutes when it gave none.
    /// @example throttle(id.key, answer) // .throttled(until: in two minutes)
    private func throttle(_ key: String, _ answer: HTTPAnswer) -> UsageReadOutcome {
        let wait = answer.headers["retry-after"].flatMap(TimeInterval.init) ?? Self.defaultWait
        let until = now().addingTimeInterval(wait)
        throttledUntil[key] = until
        return .throttled(until: until)
    }
}
