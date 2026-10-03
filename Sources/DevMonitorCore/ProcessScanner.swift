// Portions adapted from Stray (https://github.com/steppannws/Stray),
// Copyright (c) 2026 Stepan Nikulenko, MIT License. See NOTICE.md.

import Darwin
import Foundation

/// Reads the current user's processes straight from libproc, without spawning `ps` or `lsof`.
public enum ProcessScanner {
    /// Returns a snapshot of every process owned by the current user.
    /// @example ProcessScanner.scan().first { $0.pid == getpid() }?.name // "DevMonitorApp"
    public static func scan() -> [ProcessSnapshot] {
        allPids().compactMap(snapshot)
    }

    /// Returns the snapshot of one running process, or nil when it is gone, belongs to another user or has no readable path.
    /// @example ProcessScanner.snapshot(of: getpid())?.ppid // the shell's pid
    public static func snapshot(of pid: Int32) -> ProcessSnapshot? {
        guard let info = basicInfo(of: pid), info.pbi_uid == getuid() else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX) * 4)
        proc_pidpath(pid, &buffer, UInt32(buffer.count))
        let path = String(cString: buffer)
        guard !path.isEmpty else { return nil }
        let usage = ProcessUsage.of(pid)
        return ProcessSnapshot(
            pid: pid, ppid: Int32(info.pbi_ppid), startTime: UInt64(info.pbi_start_tvsec), executablePath: path,
            arguments: ProcessArguments.of(pid) ?? [path], workingDirectory: workingDirectory(of: pid),
            ports: ListeningPorts.of(pid), memoryBytes: usage.memoryBytes, cpuTimeNs: usage.cpuTimeNs)
    }

    /// Returns the pids of all running processes.
    /// @example allPids().contains(1) // true
    private static func allPids() -> [Int32] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(count) * 2)
        let filled = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size))
        return filled > 0 ? pids.prefix(Int(filled)).filter { $0 > 0 } : []
    }

    /// Returns the BSD info of a process, or nil when it is gone or unreadable.
    /// @example basicInfo(of: 1)?.pbi_ppid // 0
    private static func basicInfo(of pid: Int32) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        return proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size ? info : nil
    }

    /// Returns the current working directory of a process, or nil when it is not readable.
    /// @example workingDirectory(of: 4242) // "/Users/me/acme/worktrees/feat-123/packages/ui"
    private static func workingDirectory(of pid: Int32) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafePointer(to: &info.pvi_cdir.vip_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
        return path.isEmpty ? nil : path
    }
}
