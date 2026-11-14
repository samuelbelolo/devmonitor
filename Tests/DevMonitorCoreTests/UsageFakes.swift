import DevMonitorCore
import Foundation

/// Stand-ins for the provider, the keychain and the clock, so the sign-in and the reads run without either.
enum UsageFakes {
    static let start = Date(timeIntervalSince1970: 1_795_000_000)
    static let account = AccountID(account: "11111111-2222-3333-4444-555555555555", organization: "66666666-7777-8888-9999-000000000000", email: "dev@example.com")

    /// Returns a sign-in whose access token ends `accessLeft` seconds after `start` and whose own deadline is 28 days later.
    /// @example signIn("a1", "r1").accessToken // "a1"
    static func signIn(_ access: String, _ refresh: String, accessLeft: TimeInterval = 8 * 3600, deadline: TimeInterval = 28 * 86_400) -> SignIn {
        SignIn(accessToken: access, refreshToken: refresh, accessExpiresAt: start.addingTimeInterval(accessLeft),
               expiresAt: start.addingTimeInterval(deadline), account: account)
    }

    /// Returns the body of a token answer as the provider gives it, with made-up values.
    /// @example tokenAnswer(access: "a2", refresh: "r2") // {"access_token": "a2", …}
    static func tokenAnswer(access: String, refresh: String?, withAccount: Bool = true) -> Data {
        var answer: [String: Any] = ["token_type": "Bearer", "access_token": access, "expires_in": 28_800, "scope": "user:profile",
                                     "refresh_token_expires_in": 2_400_000, "token_uuid": "t"]
        if let refresh { answer["refresh_token"] = refresh }
        if withAccount {
            answer["account"] = ["uuid": account.account, "email_address": account.email]
            answer["organization"] = ["uuid": account.organization, "name": "Example"]
        }
        return try! JSONSerialization.data(withJSONObject: answer)
    }

    /// The body of a usage answer: the week at 15 %, Fable at 17 %.
    static let usageAnswer = Data(#"{"five_hour": null, "limits": [{"kind": "weekly_all", "percent": 15, "resets_at": "2026-11-21T04:00:00+00:00", "scope": null}, {"kind": "weekly_scoped", "percent": 17, "resets_at": "2026-11-21T04:00:00+00:00", "scope": {"model": {"display_name": "Fable"}}}]}"#.utf8)
}

/// A clock the test moves by hand.
final class FakeClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = UsageFakes.start

    var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    /// Moves the clock forward.
    /// @example clock.advance(by: 60)
    func advance(by seconds: TimeInterval) {
        lock.lock()
        current = current.addingTimeInterval(seconds)
        lock.unlock()
    }
}

/// A provider that answers from a script and records what it was sent.
actor FakeProvider: HTTPTransport {
    enum Reply {
        case answer(Int, Data, [String: String] = [:])
        case offline
    }

    /// What it answers each kind of request with, in order; the last reply of a kind repeats.
    private var replies: [String: [Reply]]
    private(set) var sent: [URLRequest] = []
    /// How long each answer takes, so that two reads can overlap.
    private let delay: Duration

    init(usage: [Reply] = [], renewal: [Reply] = [], signIn: [Reply] = [], spend: [Reply] = [], delay: Duration = .zero) {
        replies = ["usage": usage, "renewal": renewal, "signIn": signIn, "spend": spend]
        self.delay = delay
    }

    /// Answers a request with the next reply of its kind.
    /// @example try await provider.send(request).status // 200
    func send(_ request: URLRequest) async throws -> HTTPAnswer {
        sent.append(request)
        let kind = Self.kind(of: request)
        if delay != .zero { try await Task.sleep(for: delay) }
        guard let queue = replies[kind], let reply = queue.first else { throw URLError(.cannotConnectToHost) }
        if queue.count > 1 { replies[kind] = Array(queue.dropFirst()) }
        switch reply {
        case .answer(let status, let body, let headers): return HTTPAnswer(status: status, body: body, headers: headers)
        case .offline: throw URLError(.notConnectedToInternet)
        }
    }

    /// The requests of one kind sent so far.
    /// @example await provider.sent(.usage).count // 1
    func sent(_ kind: String) -> [URLRequest] {
        sent.filter { Self.kind(of: $0) == kind }
    }

    /// Tells a usage read, a renewal, a sign-in and the spending of a reset apart.
    /// @example kind(of: usageRequest) // "usage"
    static func kind(of request: URLRequest) -> String {
        guard request.httpMethod == "POST" else { return "usage" }
        let path = request.url?.path ?? ""
        if path.hasSuffix("/reset_rate_limits") || path.hasSuffix("/consume") { return "spend" }
        let body = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: String]
        return body?["grant_type"] == "refresh_token" ? "renewal" : "signIn"
    }
}

/// A vault in memory, which can be told to refuse the next saves.
final class MemoryVault: SignInVault, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String: SignIn] = [:]
    private var refusedSaves = 0
    private(set) var saves = 0

    init(_ signIns: [SignIn] = []) {
        for signIn in signIns { stored[signIn.account.key] = signIn }
    }

    /// Makes the next `count` saves fail.
    /// @example vault.refuseSaves(1)
    func refuseSaves(_ count: Int) {
        lock.lock()
        refusedSaves = count
        lock.unlock()
    }

    func save(_ signIn: SignIn) throws {
        lock.lock()
        defer { lock.unlock() }
        guard refusedSaves == 0 else {
            refusedSaves -= 1
            throw SignInVaultError.notSaved
        }
        saves += 1
        stored[signIn.account.key] = signIn
    }

    func signIn(for key: String) throws -> SignIn? {
        lock.lock()
        defer { lock.unlock() }
        return stored[key]
    }

    func remove(key: String) throws {
        lock.lock()
        stored[key] = nil
        lock.unlock()
    }
}
