import Foundation

/// One process as seen during a scan.
public struct ProcessSnapshot: Equatable, Sendable {
    public let pid: Int32
    public let ppid: Int32
    /// Start time in seconds since 1970; with the pid, it identifies a process across scans.
    public let startTime: UInt64
    public let executablePath: String
    public let arguments: [String]
    public let workingDirectory: String?
    public let ports: [UInt16]
    public let memoryBytes: UInt64
    public let cpuTimeNs: UInt64

    public init(
        pid: Int32, ppid: Int32, startTime: UInt64, executablePath: String, arguments: [String],
        workingDirectory: String?, ports: [UInt16], memoryBytes: UInt64, cpuTimeNs: UInt64
    ) {
        self.pid = pid
        self.ppid = ppid
        self.startTime = startTime
        self.executablePath = executablePath
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.ports = ports
        self.memoryBytes = memoryBytes
        self.cpuTimeNs = cpuTimeNs
    }

    /// The pid and start time together: the same process across scans, even after its pid was reused.
    public var identity: String { "\(pid)-\(startTime)" }
    /// The executable's file name, e.g. "node".
    public var name: String { (executablePath as NSString).lastPathComponent }
}
