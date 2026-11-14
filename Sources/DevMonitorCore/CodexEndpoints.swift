import Foundation

/// The requests DevMonitor sends to OpenAI for a Codex account: the sign-in page, the code exchange, the renewal and
/// the usage read. The sign-in is the Codex client's own; the usage read sends the token and nothing else.
public enum CodexEndpoints {
    /// The Codex client's public client id: OpenAI has no other one for a ChatGPT sign-in.
    public static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    public static let scope = "openid profile email offline_access"
    private static let authorizePage = URL(string: "https://auth.openai.com/oauth/authorize")!
    private static let tokenAddress = URL(string: "https://auth.openai.com/oauth/token")!
    private static let usageAddress = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private static let spendAddress = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits/consume")!
    /// The characters a form or query value keeps as they are; everything else is percent-encoded.
    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    /// Returns the page where the account's owner allows DevMonitor to read its usage.
    /// @example CodexEndpoints.authorize(redirectURI: "http://127.0.0.1:1455/auth/callback", challenge: "c", state: "s").host // "auth.openai.com"
    public static func authorize(redirectURI: String, challenge: String, state: String) -> URL {
        var components = URLComponents(url: authorizePage, resolvingAgainstBaseURL: false)!
        components.percentEncodedQuery = encoded([
            ("response_type", "code"), ("client_id", clientID), ("redirect_uri", redirectURI), ("scope", scope),
            ("code_challenge", challenge), ("code_challenge_method", "S256"), ("id_token_add_organizations", "true"),
            ("codex_cli_simplified_flow", "true"), ("originator", "codex_cli_rs"), ("state", state),
        ])
        return components.url!
    }

    /// Returns the request that turns the code the browser brought back into tokens, sent as a form.
    /// @example CodexEndpoints.exchange(code: "k", verifier: "v", redirectURI: uri).httpMethod // "POST"
    public static func exchange(code: String, verifier: String, redirectURI: String) -> URLRequest {
        var request = URLRequest(url: tokenAddress, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = Data(encoded([("grant_type", "authorization_code"), ("client_id", clientID), ("code", code),
                                         ("redirect_uri", redirectURI), ("code_verifier", verifier)]).utf8)
        return request
    }

    /// Returns the request that renews a sign-in, sent as JSON: it answers a new pair of tokens.
    /// @example CodexEndpoints.renewal(refreshToken: "r").url?.host // "auth.openai.com"
    public static func renewal(refreshToken: String) -> URLRequest {
        var request = URLRequest(url: tokenAddress, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["client_id": clientID, "grant_type": "refresh_token", "refresh_token": refreshToken], options: .sortedKeys)
        return request
    }

    /// Returns the request that reads an account's limits.
    /// @example CodexEndpoints.usage(accessToken: "a").value(forHTTPHeaderField: "Authorization") // "Bearer a"
    public static func usage(accessToken: String) -> URLRequest {
        var request = URLRequest(url: usageAddress, timeoutInterval: 30)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    /// Returns the request that spends one reset, the official Codex client's own call; OpenAI picks which one.
    /// `requestID` is made once per confirmed click, so a request sent again is the same one to OpenAI.
    /// @example CodexEndpoints.spendReset(accessToken: "a", accountID: "cx", requestID: "r").httpMethod // "POST"
    public static func spendReset(accessToken: String, accountID: String, requestID: String) -> URLRequest {
        var request = URLRequest(url: spendAddress, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !accountID.isEmpty { request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-ID") }
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["redeem_request_id": requestID], options: .sortedKeys)
        return request
    }

    /// Returns name-value pairs as a percent-encoded query or form.
    /// @example encoded([("a", "b c")]) // "a=b%20c"
    private static func encoded(_ pairs: [(String, String)]) -> String {
        pairs.map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: unreserved) ?? "")" }.joined(separator: "&")
    }
}
