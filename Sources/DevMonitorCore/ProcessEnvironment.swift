import Darwin
import Foundation

/// Reads the environment a process was started with, as macOS keeps it after the command line.
public enum ProcessEnvironment {
    /// Returns the named variables of a process's starting environment: a variable that is not set is absent from the
    /// answer, and nil means the environment could not be read. A session started by a person always has `HOME`.
    /// @example ProcessEnvironment.values(["HOME"], of: getpid())?["HOME"] // "/Users/me"
    public static func values(_ names: Set<String>, of pid: Int32) -> [String: String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }
        return values(names, in: Array(buffer.prefix(size)))
    }

    /// Returns the named variables found after the arguments of a KERN_PROCARGS2 block; nil when the block holds
    /// fewer arguments than it counts. Layout: argc (Int32) | executable path \0 padding | argv \0… | environment \0… \0.
    /// @example values(["X"], in: block) // ["X": "1"]
    static func values(_ names: Set<String>, in buffer: [UInt8]) -> [String: String]? {
        let headerSize = MemoryLayout<Int32>.size
        guard buffer.count > headerSize else { return nil }
        let count = Int(buffer.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
        var offset = headerSize
        while offset < buffer.count, buffer[offset] != 0 { offset += 1 }
        while offset < buffer.count, buffer[offset] == 0 { offset += 1 }
        var skipped = 0
        while offset < buffer.count, skipped < count {
            if buffer[offset] == 0 { skipped += 1 }
            offset += 1
        }
        guard skipped == count else { return nil }
        var found: [String: String] = [:]
        var start = offset
        while offset < buffer.count {
            if buffer[offset] == 0 {
                if offset == start { break }
                let entry = String(decoding: buffer[start..<offset], as: UTF8.self)
                if let equals = entry.firstIndex(of: "="), names.contains(String(entry[..<equals])) {
                    found[String(entry[..<equals])] = String(entry[entry.index(after: equals)...])
                }
                start = offset + 1
            }
            offset += 1
        }
        return found
    }
}
