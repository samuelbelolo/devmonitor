import Foundation

/// Reads the answer of Claude's token address, after a sign-in or a renewal.
public enum ClaudeTokenAnswer {
    public enum Failure: Error, Equatable {
        /// The answer lacks a field and no previous sign-in gives it.
        case missing(String)
    }

    /// Returns the sign-in an answer gives, its deadlines counted from `receivedAt`. A renewal answer that leaves out
    /// the refresh token, the account or the sign-in's deadline keeps those of `previous`.
    /// @example try ClaudeTokenAnswer.signIn(from: body, receivedAt: Date()).account.email // "dev@example.com"
    public static func signIn(from body: Data, receivedAt: Date, previous: SignIn? = nil) throws -> SignIn {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let answer = try decoder.decode(Answer.self, from: body)
        guard let accessToken = answer.accessToken else { throw Failure.missing("access_token") }
        guard let refreshToken = answer.refreshToken ?? previous?.refreshToken else { throw Failure.missing("refresh_token") }
        guard let account = account(of: answer) ?? previous?.account else { throw Failure.missing("account") }
        return SignIn(
            accessToken: accessToken, refreshToken: refreshToken,
            accessExpiresAt: receivedAt.addingTimeInterval(answer.expiresIn ?? 3600),
            expiresAt: answer.refreshTokenExpiresIn.map(receivedAt.addingTimeInterval) ?? previous?.expiresAt,
            account: account)
    }

    /// Returns the account an answer names; nil when it does not name one.
    /// @example account(of: answer)?.email // "dev@example.com"
    private static func account(of answer: Answer) -> ClaudeAccountID? {
        guard let account = answer.account?.uuid, let organization = answer.organization?.uuid else { return nil }
        return ClaudeAccountID(account: account, organization: organization, email: answer.account?.emailAddress ?? "")
    }

    /// The fields of the answer DevMonitor reads.
    private struct Answer: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let expiresIn: Double?
        let refreshTokenExpiresIn: Double?
        let account: Account?
        let organization: Organization?
    }

    /// The account the tokens read.
    private struct Account: Decodable {
        let uuid: String?
        let emailAddress: String?
    }

    /// The organisation the account reads within.
    private struct Organization: Decodable {
        let uuid: String?
    }
}
