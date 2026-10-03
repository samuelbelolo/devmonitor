import Foundation

/// Parses the tab-separated lines `DockerCLI` asks `docker ps` and `docker stats` to print.
public enum DockerOutputParser {
    /// Largest size believed: beyond it the figure is not a container's memory, and sums could overflow.
    private static let largestSize = 1e15

    /// Returns the Compose containers of a listing whose lines are "id, name, Compose project, Compose directory".
    /// @example containers(from: "abc123\tshop-cache-1\tshop\t/Users/me/acme/shop").first?.name // "shop-cache-1"
    public static func containers(from output: String) -> [DockerContainer] {
        output.split(separator: "\n").compactMap { line in
            // The directory comes last and takes the rest of the line, so nothing in it can pass for another field.
            let fields = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 4, !fields[0].isEmpty, !fields[2].isEmpty, !fields[3].isEmpty else { return nil }
            return DockerContainer(
                id: fields[0], name: DisplayText.clean(fields[1]), projectRoot: fields[3],
                projectName: DisplayText.clean(fields[2]), memoryBytes: 0)
        }
    }

    /// Returns the memory used by each container id from lines of "id, memory usage".
    /// @example memory(from: "abc123\t45.5MiB / 7.6GiB") // ["abc123": 47_710_208]
    public static func memory(from output: String) -> [String: UInt64] {
        var result: [String: UInt64] = [:]
        for line in output.split(separator: "\n") {
            let fields = line.split(separator: "\t", maxSplits: 1)
            guard fields.count == 2, let used = fields[1].split(separator: "/").first else { continue }
            result[String(fields[0])] = bytes(used.trimmingCharacters(in: .whitespaces))
        }
        return result
    }

    /// Converts a Docker size such as "45.5MiB" to bytes; a size that is not a plausible number counts as zero.
    /// @example bytes("1.2GiB") // 1_288_490_188
    private static func bytes(_ size: String) -> UInt64 {
        let units: [(String, Double)] = [("GiB", 1_073_741_824), ("MiB", 1_048_576), ("KiB", 1_024), ("GB", 1e9), ("MB", 1e6), ("kB", 1e3), ("B", 1)]
        for (suffix, factor) in units where size.hasSuffix(suffix) {
            let value = (Double(size.dropLast(suffix.count)) ?? 0) * factor
            return value.isFinite && value >= 0 && value < largestSize ? UInt64(value) : 0
        }
        return 0
    }
}
