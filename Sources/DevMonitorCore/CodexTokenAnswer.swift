import Foundation

/// Reads the answer of OpenAI's token address for a Codex account, after a sign-in or a renewal.
public enum CodexTokenAnswer {
    /// The namespace of the id token's claims that names the ChatGPT account.
    private static let authClaims = "https://api.openai.com/auth"

    /// Returns the sign-in an answer gives, its deadlines counted from `receivedAt`. The account comes from the id
    /// token; a renewal answer that leaves out the id token or the refresh token keeps those of `previous`.
    /// @example try CodexTokenAnswer.signIn(from: body, receivedAt: Date()).account.provider // .codex
    public static func signIn(from body: Data, receivedAt: Date, previous: SignIn? = nil) throws -> SignIn {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let answer = try decoder.decode(Answer.self, from: body)
        guard let accessToken = answer.accessToken else { throw ClaudeTokenAnswer.Failure.missing("access_token") }
        guard let refreshToken = answer.refreshToken ?? previous?.refreshToken else { throw ClaudeTokenAnswer.Failure.missing("refresh_token") }
        guard let account = answer.idToken.flatMap(account(of:)) ?? previous?.account else { throw ClaudeTokenAnswer.Failure.missing("id_token") }
        return SignIn(
            accessToken: accessToken, refreshToken: refreshToken,
            accessExpiresAt: receivedAt.addingTimeInterval(answer.expiresIn ?? 3600),
            expiresAt: previous?.expiresAt, account: account,
            renewAfter: answer.earliestRefreshAt.map { Date(timeIntervalSince1970: $0) })
    }

    /// Returns the account an id token names: its ChatGPT account and email; nil when it names none.
    /// @example account(of: idToken)?.email // "dev@example.com"
    private static func account(of idToken: String) -> AccountID? {
        guard let claims = payload(of: idToken),
              let auth = claims[authClaims] as? [String: Any],
              let id = auth["chatgpt_account_id"] as? String, !id.isEmpty else { return nil }
        return AccountID(provider: .codex, account: id, organization: "", email: claims["email"] as? String ?? "")
    }

    /// Returns the claims of a JWT, read without checking its signature: they only name the account, and the token
    /// came straight from OpenAI over TLS.
    /// @example payload(of: "e30.eyJlbWFpbCI6ImEifQ.c2ln")?["email"] // "a"
    private static func payload(of token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// The fields of the answer DevMonitor reads.
    private struct Answer: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let idToken: String?
        let expiresIn: Double?
        let earliestRefreshAt: Double?
    }
}
