// Portions adapted from Stray (https://github.com/steppannws/Stray),
// Copyright (c) 2026 Stepan Nikulenko, MIT License. See NOTICE.md.

import Darwin
import Foundation

/// Reads the command line of a process.
enum ProcessArguments {
    /// Returns the argv of a process through sysctl KERN_PROCARGS2, or nil when it is not readable.
    /// @example ProcessArguments.of(4242) // ["node", "/Users/me/repo/node_modules/.bin/vite"]
    static func of(_ pid: Int32) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }
        // Layout: argc (Int32) | exec_path \0 padding | argv[0] \0 argv[1] \0 …
        let count = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        var offset = MemoryLayout<Int32>.size
        while offset < size, buffer[offset] != 0 { offset += 1 }
        while offset < size, buffer[offset] == 0 { offset += 1 }
        var arguments: [String] = []
        var current: [UInt8] = []
        while offset < size, arguments.count < Int(count) {
            if buffer[offset] == 0 {
                arguments.append(String(decoding: current, as: UTF8.self))
                current.removeAll()
            } else {
                current.append(buffer[offset])
            }
            offset += 1
        }
        return arguments.isEmpty ? nil : arguments
    }
}
