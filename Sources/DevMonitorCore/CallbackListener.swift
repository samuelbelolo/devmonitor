import Foundation
import Network

/// Listens on this Mac's loopback, for the time of a sign-in, for the browser coming back from the authorization page.
/// Only a program of this Mac can reach it, and it keeps the query of the first `GET /callback` it receives.
public final class CallbackListener: @unchecked Sendable {
    private static let page = "<!doctype html><meta charset=utf-8><title>DevMonitor</title>"
        + "<p style=\"font:16px -apple-system,sans-serif;margin:40px\">DevMonitor received the sign-in. You can close this tab.</p>"

    private let listener: NWListener
    private let path: String
    private let queue = DispatchQueue(label: "local.devmonitor.sign-in-callback")
    private let lock = NSLock()
    private var answer: Result<[String: String], Error>?
    private var waiters: [CheckedContinuation<[String: String], Error>] = []
    private var readyPort: UInt16 = 0

    /// Prepares a listener on this port of the loopback, any free one when nil, for the browser coming back on `path`.
    /// @example try CallbackListener(port: 1455, path: "/auth/callback")
    public init(port: UInt16? = nil, path: String = "/callback") throws {
        let parameters = NWParameters.tcp
        parameters.acceptLocalOnly = true
        parameters.requiredInterfaceType = .loopback
        listener = try NWListener(using: parameters, on: port.flatMap(NWEndpoint.Port.init(rawValue:)) ?? .any)
        self.path = path
    }

    /// The port the listener got; 0 until it is started.
    public var port: UInt16 {
        lock.lock()
        defer { lock.unlock() }
        return readyPort
    }

    /// Starts listening and returns once the port is known.
    /// @example try await listener.start(); listener.port // 54321
    public func start() async throws {
        let once = Once()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.setPort(self?.listener.port?.rawValue ?? 0)
                    once.run { continuation.resume() }
                case .failed(let error):
                    once.run { continuation.resume(throwing: error) }
                case .cancelled:
                    once.run { continuation.resume(throwing: CancellationError()) }
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in self?.serve(connection) }
            listener.start(queue: queue)
        }
    }

    /// Returns the query the browser came back with; throws `noAnswer` when it has not come back after `timeout`.
    /// @example try await listener.waitForCallback(timeout: 300)["code"] // "the-code"
    public func waitForCallback(timeout: TimeInterval) async throws -> [String: String] {
        queue.asyncAfter(deadline: .now() + timeout) { [weak self] in self?.deliver(.failure(SignInFlow.Failure.noAnswer)) }
        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let answer {
                lock.unlock()
                continuation.resume(with: answer)
                return
            }
            waiters.append(continuation)
            lock.unlock()
        }
    }

    /// Stops listening.
    /// @example listener.stop()
    public func stop() {
        listener.cancel()
    }

    /// Records the port once the listener is ready.
    /// @example setPort(54321)
    private func setPort(_ port: UInt16) {
        lock.lock()
        readyPort = port
        lock.unlock()
    }

    /// Reads the request line of a connection, answers it, and keeps the query of a `GET /callback`.
    /// @example serve(connection)
    private func serve(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, _ in
            let request = data.map { String(decoding: $0, as: UTF8.self) } ?? ""
            let target = request.split(separator: " ", maxSplits: 2).dropFirst().first.map(String.init) ?? ""
            let components = URLComponents(string: target)
            guard request.hasPrefix("GET "), components?.path == self?.path, let items = components?.queryItems else {
                Self.respond(connection, status: "404 Not Found", body: "")
                return
            }
            Self.respond(connection, status: "200 OK", body: Self.page)
            self?.deliver(.success(Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })))
        }
    }

    /// Sends a short HTTP answer and closes the connection.
    /// @example respond(connection, status: "200 OK", body: page)
    private static func respond(_ connection: NWConnection, status: String, body: String) {
        let bytes = Data(body.utf8)
        let head = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(bytes.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(head.utf8) + bytes, completion: .contentProcessed { _ in connection.cancel() })
    }

    /// Keeps the first answer, a query or a failure, and hands it to whoever waits.
    /// @example deliver(.success(["code": "k", "state": "s"]))
    private func deliver(_ result: Result<[String: String], Error>) {
        lock.lock()
        guard answer == nil else {
            lock.unlock()
            return
        }
        answer = result
        let waiting = waiters
        waiters = []
        lock.unlock()
        for waiter in waiting { waiter.resume(with: result) }
    }
}

/// Runs a closure the first time it is asked to, and never again.
private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    /// Runs `work` unless it already ran.
    /// @example once.run { continuation.resume() }
    func run(_ work: () -> Void) {
        lock.lock()
        let first = !done
        done = true
        lock.unlock()
        if first { work() }
    }
}
