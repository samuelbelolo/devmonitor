import Foundation

/// What a server answered: its status, its body and its headers, named in lowercase.
public struct HTTPAnswer: Sendable {
    public let status: Int
    public let body: Data
    public let headers: [String: String]

    public init(status: Int, body: Data, headers: [String: String] = [:]) {
        self.status = status
        self.body = body
        self.headers = headers
    }
}

/// Sends a request and returns the answer; throws only when no answer came, never on an HTTP error.
public protocol HTTPTransport: Sendable {
    /// Sends one request.
    /// @example try await transport.send(ClaudeEndpoints.usage(accessToken: token)).status // 200
    func send(_ request: URLRequest) async throws -> HTTPAnswer
}

/// The transport the app uses: a session that keeps no cookie and no cache, so nothing of an answer outlives it.
public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
    }

    /// Sends one request through the session.
    /// @example try await URLSessionTransport().send(request).status // 200
    public func send(_ request: URLRequest) async throws -> HTTPAnswer {
        let (body, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        var headers: [String: String] = [:]
        for (name, value) in http.allHeaderFields {
            headers[String(describing: name).lowercased()] = String(describing: value)
        }
        return HTTPAnswer(status: http.statusCode, body: body, headers: headers)
    }
}
