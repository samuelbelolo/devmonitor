import Darwin
import Foundation

/// The swap a Mac has in use, beside the memory it has installed.
public struct SwapUsage: Sendable, Equatable {
    public let usedBytes: UInt64
    public let installedBytes: UInt64

    public init(usedBytes: UInt64, installedBytes: UInt64) {
        self.usedBytes = usedBytes
        self.installedBytes = installedBytes
    }

    /// Fine up to a quarter of the installed memory, high above it, critical above half; fine when the installed
    /// memory is unknown.
    public var state: SwapState {
        if usedBytes > installedBytes / 2, installedBytes > 0 { return .critical }
        return usedBytes > installedBytes / 4 && installedBytes > 0 ? .high : .fine
    }

    /// Reads the swap in use and the installed memory of this Mac; nil when the system does not say.
    /// @example SwapUsage.read()?.state // .fine
    public static func read() -> SwapUsage? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return nil }
        return SwapUsage(usedBytes: usage.xsu_used, installedBytes: ProcessInfo.processInfo.physicalMemory)
    }
}
