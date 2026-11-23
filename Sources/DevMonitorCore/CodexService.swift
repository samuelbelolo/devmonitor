import Foundation

/// Reading Codex accounts.
public struct CodexService: UsageService {
    public init() {}

    public func renewal(of signIn: SignIn) -> URLRequest {
        CodexEndpoints.renewal(refreshToken: signIn.refreshToken)
    }

    public func usageRequest(for signIn: SignIn) -> URLRequest {
        CodexEndpoints.usage(accessToken: signIn.accessToken)
    }

    public func renewed(from body: Data, receivedAt: Date, previous: SignIn) throws -> SignIn {
        try CodexTokenAnswer.signIn(from: body, receivedAt: receivedAt, previous: previous)
    }

    public func usage(from body: Data) throws -> AccountUsage {
        try CodexUsageAnswer.usage(from: body)
    }

    public func spendRequest(_ credit: ResetCredit, for signIn: SignIn, requestID: String) -> URLRequest? {
        CodexEndpoints.spendReset(accessToken: signIn.accessToken, accountID: signIn.account.account, requestID: requestID)
    }

    /// OpenAI answers a `code`: `reset`, or `already_redeemed` for a request it already took, means the reset is used;
    /// `nothing_to_reset` and `no_credit` mean it is kept (the official client reads them the same way).
    public func spendOutcome(status: Int, body: Data) -> ResetSpendOutcome {
        let answer = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        guard (200..<300).contains(status) else {
            return (400..<500).contains(status) ? .refused(status: status, reason: answer?["message"] as? String ?? answer?["detail"] as? String) : .unknown
        }
        switch answer?["code"] as? String {
        case "reset", "already_redeemed": return .spent
        case "nothing_to_reset": return .nothingToReset
        case "no_credit": return .noneLeft
        default: return .unknown
        }
    }
}
