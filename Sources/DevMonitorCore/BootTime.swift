import Darwin
import Foundation

/// When this Mac last started.
public enum BootTime {
    /// Returns the date of the last start; nil when the system does not say.
    /// @example BootTime.read() // 2026-11-03 09:14:37 +0000
    public static func read() -> Date? {
        var started = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &started, &size, nil, 0) == 0, started.tv_sec > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(started.tv_sec))
    }
}
