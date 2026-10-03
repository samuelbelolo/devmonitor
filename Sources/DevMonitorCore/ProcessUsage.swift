import Darwin
import Foundation

/// The memory and CPU time a process has used.
struct ProcessUsage {
    /// Physical footprint, the "Memory" column of Activity Monitor.
    let memoryBytes: UInt64
    let cpuTimeNs: UInt64

    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    /// Returns the memory footprint and total CPU time of a process, zero when it is not readable.
    /// @example ProcessUsage.of(4242).memoryBytes // 167_772_160
    static func of(_ pid: Int32) -> ProcessUsage {
        var usage = rusage_info_v4()
        let status = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
        }
        guard status == 0 else { return ProcessUsage(memoryBytes: 0, cpuTimeNs: 0) }
        // CPU times are in Mach time units, not nanoseconds, on Apple Silicon.
        let ticks = usage.ri_user_time + usage.ri_system_time
        return ProcessUsage(memoryBytes: usage.ri_phys_footprint, cpuTimeNs: ticks * UInt64(timebase.numer) / UInt64(timebase.denom))
    }
}
