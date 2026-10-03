import Foundation

/// Runs a command-line tool without a shell and returns what it printed.
public enum CommandRunner {
    /// Longest wait for the end of the output once the tool has exited: a child it started can keep the pipe open.
    private static let outputGrace: TimeInterval = 0.5

    /// Runs an executable with arguments; nil when it cannot start, fails, or has not finished after `timeout` seconds.
    /// Its standard error is discarded, so a chatty tool can never block on a full pipe. `environment` replaces the
    /// app's own when given.
    /// @example CommandRunner.run("/usr/bin/sw_vers", ["-productVersion"], timeout: 5) // "15.0\n"
    public static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval, environment: [String: String]? = nil) -> String? {
        let process = Process()
        let output = Pipe()
        let collected = CollectedOutput()
        let exited = DispatchSemaphore(value: 0)
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment { process.environment = environment }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { _ in exited.signal() }
        output.fileHandleForReading.readabilityHandler = { handle in collected.append(handle.availableData, from: handle) }
        defer { output.fileHandleForReading.readabilityHandler = nil }
        guard (try? process.run()) != nil else { return nil }
        guard exited.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            return nil
        }
        collected.waitForEnd(upTo: outputGrace)
        return process.terminationStatus == 0 ? String(decoding: collected.data, as: UTF8.self) : nil
    }
}

/// The output of a command, read as it arrives so a full pipe never blocks the command.
private final class CollectedOutput: @unchecked Sendable {
    private let lock = NSLock()
    private var bytes = Data()
    private let ended = DispatchSemaphore(value: 0)

    /// Adds a chunk read from the pipe; an empty chunk is the end of the output.
    /// @example collected.append(handle.availableData, from: handle)
    func append(_ chunk: Data, from handle: FileHandle) {
        guard !chunk.isEmpty else {
            handle.readabilityHandler = nil
            ended.signal()
            return
        }
        lock.lock()
        bytes.append(chunk)
        lock.unlock()
    }

    /// Waits for the end of the output, at most `seconds`.
    /// @example collected.waitForEnd(upTo: 0.5)
    func waitForEnd(upTo seconds: TimeInterval) {
        _ = ended.wait(timeout: .now() + seconds)
    }

    /// Everything read so far.
    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return bytes
    }
}
