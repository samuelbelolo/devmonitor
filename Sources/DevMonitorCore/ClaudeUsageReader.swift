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

/// Reads the usage of Claude accounts and renews their sign-ins.
///
/// A renewal answers a new pair of tokens and ends the access token in use at once, so the new pair is kept before
/// anything else: in the vault, and in memory when the vault refused it, to be saved again on the next read. Reads of
/// the same account never overlap, so a refresh token is never spent twice.
public actor ClaudeUsageReader {
    /// How long a refusal without a delay holds the next read of an account back.
    private static let defaultWait: TimeInterval = 600

    private let vault: SignInVault
    private let transport: HTTPTransport
    private let now: @Sendable () -> Date
    /// The latest pair of each account, which may be newer than the vault's.
    private var current: [String: SignIn] = [:]
    /// The accounts whose latest pair the vault refused.
    private var unsaved: Set<String> = []
    private var throttledUntil: [String: Date] = [:]
    private var running: [String: Task<UsageReadOutcome, Never>] = [:]

    public init(vault: SignInVault, transport: HTTPTransport, now: @escaping @Sendable () -> Date = Date.init) {
        self.vault = vault
        self.transport = transport
        self.now = now
    }

    /// Reads an account; a read asked while another of the same account runs gets the same outcome.
    /// @example await reader.read(id.key) // .read(usage)
    public func read(_ key: String) async -> UsageReadOutcome {
        if let task = running[key] { return await task.value }
        let task = Task { await self.perform(key) }
        running[key] = task
        let outcome = await task.value
        running[key] = nil
        return outcome
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
    /// @example await perform(id.key) // .read(usage)
    private func perform(_ key: String) async -> UsageReadOutcome {
        if let until = throttledUntil[key], until > now() { return .throttled(until: until) }
        let held: SignIn?
        do { held = try current[key] ?? vault.signIn(for: key) } catch { return .unreachable }
        guard var signIn = held, !signIn.hasEnded(at: now()) else { return .needsSignIn }
        if unsaved.contains(key) { keepRenewed(signIn) }
        var renewed = false
        if signIn.isAccessDue(at: now()) {
            switch await renew(signIn) {
            case .renewed(let fresh): signIn = fresh
            case .stopped(let outcome): return outcome
            }
            renewed = true
        }
        while true {
            guard let answer = try? await transport.send(ClaudeEndpoints.usage(accessToken: signIn.accessToken)) else { return .unreachable }
            switch answer.status {
            case 200:
                return (try? ClaudeUsageAnswer.usage(from: answer.body)).map(UsageReadOutcome.read) ?? .unreachable
            case 401 where !renewed:
                switch await renew(signIn) {
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

    /// What a renewal gave.
    private enum Renewal {
        case renewed(SignIn)
        case stopped(UsageReadOutcome)
    }

    /// Renews a sign-in and keeps the new pair; a refusal asks for a new sign-in.
    /// @example await renew(signIn) // .renewed(fresh)
    private func renew(_ signIn: SignIn) async -> Renewal {
        let key = signIn.account.key
        guard let answer = try? await transport.send(ClaudeEndpoints.renewal(refreshToken: signIn.refreshToken)) else { return .stopped(.unreachable) }
        switch answer.status {
        case 200:
            guard let fresh = try? ClaudeTokenAnswer.signIn(from: answer.body, receivedAt: now(), previous: signIn) else { return .stopped(.unreachable) }
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
