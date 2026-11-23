import Foundation

/// Reading Claude accounts.
public struct ClaudeService: UsageService {
    public init() {}

    public func renewal(of signIn: SignIn) -> URLRequest {
        ClaudeEndpoints.renewal(refreshToken: signIn.refreshToken)
    }

    public func usageRequest(for signIn: SignIn) -> URLRequest {
        ClaudeEndpoints.usage(accessToken: signIn.accessToken)
    }

    public func renewed(from body: Data, receivedAt: Date, previous: SignIn) throws -> SignIn {
        try ClaudeTokenAnswer.signIn(from: body, receivedAt: receivedAt, previous: previous)
    }

    public func usage(from body: Data) throws -> AccountUsage {
        try ClaudeUsageAnswer.usage(from: body)
    }

    public func usageRequest(for signIn: SignIn, withResets: Bool) -> URLRequest {
        ClaudeEndpoints.usage(accessToken: signIn.accessToken, withResets: withResets)
    }

    public func spendRequest(_ credit: ResetCredit, for signIn: SignIn, requestID: String) -> URLRequest? {
        credit.id.map { ClaudeEndpoints.spendReset(accessToken: signIn.accessToken, organization: signIn.account.organization, grantID: $0, requestID: requestID) }
    }

    /// Claude answers `result: "reset"` once the reset is used, and a `reason` or an `error.message` otherwise.
    public func spendOutcome(status: Int, body: Data) -> ResetSpendOutcome {
        let answer = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        let message = (answer?["error"] as? [String: Any])?["message"] as? String ?? answer?["reason"] as? String
        switch status {
        case 200..<300: return (answer?["result"] as? String) == "reset" ? .spent : answer == nil ? .unknown : .refused(status: status, reason: message)
        case 400..<500: return .refused(status: status, reason: message)
        default: return .unknown
        }
    }
}
