import Foundation

/// What reading one provider's accounts takes: the renewal and usage requests, and how to read their answers.
public protocol UsageService: Sendable {
    /// Returns the request that renews a sign-in.
    /// @example service.renewal(of: signIn).httpMethod // "POST"
    func renewal(of signIn: SignIn) -> URLRequest
    /// Returns the request that reads an account's limits.
    /// @example service.usageRequest(for: signIn).url?.host // "api.anthropic.com"
    func usageRequest(for signIn: SignIn) -> URLRequest
    /// Returns the sign-in a renewal answer gives, keeping from `previous` what it leaves out.
    /// @example try service.renewed(from: body, receivedAt: Date(), previous: signIn).accessToken // "a2"
    func renewed(from body: Data, receivedAt: Date, previous: SignIn) throws -> SignIn
    /// Returns the limits a usage answer gives.
    /// @example try service.usage(from: body).room // 83
    func usage(from body: Data) throws -> AccountUsage

    /// Returns the request that reads an account's limits and its free resets.
    /// @example service.usageRequest(for: signIn, withResets: true).url?.query // "cedar_ember=1"
    func usageRequest(for signIn: SignIn, withResets: Bool) -> URLRequest

    /// Returns the request that spends one reset; nil when the provider cannot be told which one.
    /// @example service.spendRequest(credit, for: signIn, requestID: "r")?.httpMethod // "POST"
    func spendRequest(_ credit: ResetCredit, for signIn: SignIn, requestID: String) -> URLRequest?

    /// Returns what the answer to a spend says.
    /// @example service.spendOutcome(status: 200, body: body) // .spent
    func spendOutcome(status: Int, body: Data) -> ResetSpendOutcome
}

extension UsageService {
    /// A provider without resets reads the same way with or without them.
    /// @example service.usageRequest(for: signIn, withResets: true) == service.usageRequest(for: signIn) // true
    public func usageRequest(for signIn: SignIn, withResets: Bool) -> URLRequest { usageRequest(for: signIn) }

    /// A provider without resets spends none.
    /// @example service.spendRequest(credit, for: signIn, requestID: "r") // nil
    public func spendRequest(_ credit: ResetCredit, for signIn: SignIn, requestID: String) -> URLRequest? { nil }

    /// A provider without resets answers nothing DevMonitor can read.
    /// @example service.spendOutcome(status: 200, body: Data()) // .unknown
    public func spendOutcome(status: Int, body: Data) -> ResetSpendOutcome { .unknown }
}
