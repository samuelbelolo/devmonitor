// Portions adapted from Stray (https://github.com/steppannws/Stray),
// Copyright (c) 2026 Stepan Nikulenko, MIT License. See NOTICE.md.

import Darwin
import Foundation

/// Reads the TCP ports a process listens on.
enum ListeningPorts {
    /// Returns the listening TCP ports of a process, sorted, one entry per port even when bound on IPv4 and IPv6.
    /// @example ListeningPorts.of(4242) // [3000]
    static func of(_ pid: Int32) -> [UInt16] {
        let sizeHint = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        let capacity = Int(sizeHint) / MemoryLayout<proc_fdinfo>.stride
        guard capacity > 0 else { return [] }
        var descriptors = [proc_fdinfo](repeating: proc_fdinfo(), count: capacity)
        let filled = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &descriptors, sizeHint)
        let count = min(Int(max(filled, 0)) / MemoryLayout<proc_fdinfo>.stride, capacity)
        var ports: Set<UInt16> = []
        for descriptor in descriptors.prefix(count) where descriptor.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) {
            if let port = listeningPort(pid: pid, descriptor: descriptor.proc_fd) { ports.insert(port) }
        }
        return ports.sorted()
    }

    /// Returns the local port of a descriptor when it is a TCP socket in LISTEN state.
    /// @example listeningPort(pid: 4242, descriptor: 21) // 3000
    private static func listeningPort(pid: Int32, descriptor: Int32) -> UInt16? {
        var info = socket_fdinfo()
        let size = Int32(MemoryLayout<socket_fdinfo>.size)
        guard proc_pidfdinfo(pid, descriptor, PROC_PIDFDSOCKETINFO, &info, size) == size,
              info.psi.soi_kind == SOCKINFO_TCP
        else { return nil }
        let tcp = info.psi.soi_proto.pri_tcp
        guard tcp.tcpsi_state == TSI_S_LISTEN else { return nil }
        // insi_lport holds the port in network byte order.
        let port = UInt16(bigEndian: UInt16(truncatingIfNeeded: tcp.tcpsi_ini.insi_lport))
        return port == 0 ? nil : port
    }
}
