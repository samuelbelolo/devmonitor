import Darwin
import Foundation

/// Sends signals to processes, after checking each one is still the process that was scanned.
/// Never signals a process group: an editor, its agent sessions and their MCP servers can share one.
public struct ProcessKiller {
    private let inspect: (Int32) -> ProcessSnapshot?
    private let send: (Int32, Int32) -> Int32

    /// Creates a killer; the two parameters exist so tests can stand in for the real process table and signals.
    /// @example ProcessKiller() // signals real processes
    public init(
        inspect: @escaping (Int32) -> ProcessSnapshot? = ProcessScanner.snapshot(of:),
        send: @escaping (Int32, Int32) -> Int32 = { kill($0, $1) }
    ) {
        self.inspect = inspect
        self.send = send
    }

    /// Signals each process in the order given, looking at it again first: a pid that was recycled, a process
    /// that became another program, and anything protected are left alone.
    /// @example ProcessKiller().signal(service.members, with: SIGTERM) // [.signalled(40), .signalled(50)]
    public func signal(_ targets: [ProcessSnapshot], with signal: Int32) -> [KillOutcome] {
        targets.map { target in
            guard target.pid > 1, target.pid != getpid() else { return .refused(target.pid) }
            guard let running = inspect(target.pid), running.startTime == target.startTime else { return .gone(target.pid) }
            guard ProcessRole.of(running).isCandidate, ProcessRole.of(target).isCandidate else { return .refused(target.pid) }
            guard running.executablePath == target.executablePath else { return .gone(target.pid) }
            return send(target.pid, signal) == 0 ? .signalled(target.pid) : .failed(target.pid)
        }
    }
}
