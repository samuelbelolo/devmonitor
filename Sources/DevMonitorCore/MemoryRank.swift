import Foundation

/// The order lists are shown in.
enum MemoryRank {
    /// Returns a sort key: heaviest first by steps of 256 MB, then by name, so small memory changes never reorder a list.
    /// @example MemoryRank.key(300 * 1_048_576, "a") < MemoryRank.key(100 * 1_048_576, "b") // true
    static func key(_ memoryBytes: UInt64, _ name: String) -> (Int64, String) {
        (-Int64(memoryBytes / (256 * 1_048_576)), name)
    }
}
