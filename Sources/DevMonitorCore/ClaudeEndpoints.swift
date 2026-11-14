import Foundation

/// The requests DevMonitor sends to Claude: the sign-in page, the token exchange, the renewal and the usage read.
/// The sign-in asks to read the profile only, and the usage read does not call itself Claude Code.
public enum ClaudeEndpoints {
    /// Claude Code's public client id: Anthropic has no other one to sign in with.
    public static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    /// Reading the profile is enough to read the usage; the token cannot run a model or create a key.
    public static let scope = "user:profile"
    private static let authorizePage = URL(string: "https://claude.ai/oauth/authorize")!
    private static let tokenAddress = URL(string: "https://api.anthropic.com/v1/oauth/token")!
    private static let usageAddress = URL(string: "https://api.anthropic.com/api/oauth/usage")!
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

    /// Returns the request that reads an account's limits.
    /// @example ClaudeEndpoints.usage(accessToken: "a").value(forHTTPHeaderField: "Authorization") // "Bearer a"
    public static func usage(accessToken: String) -> URLRequest {
        var request = URLRequest(url: usageAddress, timeoutInterval: 30)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
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
