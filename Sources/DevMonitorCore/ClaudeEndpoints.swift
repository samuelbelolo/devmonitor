import Foundation

/// The requests DevMonitor sends to Claude: the sign-in page, the token exchange, the renewal, the usage read and the
/// spending of a free reset. The sign-in asks to read the profile only. The usage read calls itself Claude Code only
/// when it asks for the free resets, which Claude lists to Claude Code alone; the timer's reads never do. Spending a
/// reset, on its owner's click, is the one request that changes anything on the account.
public enum ClaudeEndpoints {
    /// Claude Code's public client id: Anthropic has no other one to sign in with.
    public static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    /// Reading the profile is enough to read the usage; the token cannot run a model or create a key.
    public static let scope = "user:profile"
    private static let authorizePage = URL(string: "https://claude.ai/oauth/authorize")!
    private static let tokenAddress = URL(string: "https://api.anthropic.com/v1/oauth/token")!
    private static let usageAddress = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private static let resetsAddress = URL(string: "https://api.anthropic.com/api/oauth/usage?cedar_ember=1")!
    /// The Claude Code version the reads for resets present; Claude lists the resets to Claude Code's command line.
    static let claudeCodeAgent = "claude-cli/2.1.325 (external, cli)"
    /// The characters a query value keeps as they are; everything else is percent-encoded.
    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    /// Returns the address of the page where the account's owner allows DevMonitor to read its usage.
    /// @example ClaudeEndpoints.authorize(redirectURI: "http://localhost:4321/callback", challenge: "c", state: "s").host // "claude.ai"
    public static func authorize(redirectURI: String, challenge: String, state: String) -> URL {
        let query: [(String, String)] = [
            ("code", "true"), ("client_id", clientID), ("response_type", "code"), ("redirect_uri", redirectURI),
            ("scope", scope), ("code_challenge", challenge), ("code_challenge_method", "S256"), ("state", state),
        ]
        var components = URLComponents(url: authorizePage, resolvingAgainstBaseURL: false)!
        components.percentEncodedQuery = query.map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: unreserved) ?? "")" }.joined(separator: "&")
        return components.url!
    }

    /// Returns the request that turns the code the browser brought back into tokens.
    /// @example ClaudeEndpoints.exchange(code: "k", state: "s", verifier: "v", redirectURI: "http://localhost:1/callback").httpMethod // "POST"
    public static func exchange(code: String, state: String, verifier: String, redirectURI: String) -> URLRequest {
        tokenRequest(["code": code, "state": state, "grant_type": "authorization_code", "client_id": clientID,
                      "redirect_uri": redirectURI, "code_verifier": verifier])
    }

    /// Returns the request that renews a sign-in: it answers a new pair of tokens and ends the access token in use.
    /// @example ClaudeEndpoints.renewal(refreshToken: "r").url?.path // "/v1/oauth/token"
    public static func renewal(refreshToken: String) -> URLRequest {
        tokenRequest(["grant_type": "refresh_token", "refresh_token": refreshToken, "client_id": clientID])
    }

    /// Returns the request that reads an account's limits, and its free resets too when `withResets` is set.
    /// @example ClaudeEndpoints.usage(accessToken: "a").value(forHTTPHeaderField: "Authorization") // "Bearer a"
    public static func usage(accessToken: String, withResets: Bool = false) -> URLRequest {
        var request = URLRequest(url: withResets ? resetsAddress : usageAddress, timeoutInterval: 30)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        if withResets { request.setValue(claudeCodeAgent, forHTTPHeaderField: "User-Agent") }
        return request
    }

    /// Returns the request that spends one reset of a grant; `requestID` is made once per confirmed click, so a
    /// request sent again after a renewal is the same one to Claude.
    /// @example ClaudeEndpoints.spendReset(accessToken: "a", organization: "o", grantID: "g", requestID: "r").httpMethod // "POST"
    public static func spendReset(accessToken: String, organization: String, grantID: String, requestID: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/organizations/\(organization)/reset_rate_limits")!, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(claudeCodeAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let fields = ["program": "cedar_ember", "grant_id": grantID, "request_id": requestID]
        request.httpBody = try? JSONSerialization.data(withJSONObject: fields, options: .sortedKeys)
        return request
    }

    /// Returns a POST of these fields as JSON to the token address.
    /// @example tokenRequest(["grant_type": "refresh_token"]).httpMethod // "POST"
    private static func tokenRequest(_ fields: [String: String]) -> URLRequest {
        var request = URLRequest(url: tokenAddress, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(withJSONObject: fields, options: .sortedKeys)
        return request
    }
}
