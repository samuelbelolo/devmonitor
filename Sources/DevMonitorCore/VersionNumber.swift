import Foundation

/// A version such as 2.1.288, compared number by number.
public struct VersionNumber: Comparable, Sendable, CustomStringConvertible {
    public let text: String
    private let parts: [Int]

    /// Reads the first version found in a text, such as the output of `claude --version`; nil when there is none.
    /// @example VersionNumber(parsing: "codex-cli 0.160.0")?.text // "0.160.0"
    public init?(parsing output: String) {
        guard let range = output.range(of: #"\d+(\.\d+)+"#, options: .regularExpression) else { return nil }
        text = String(output[range])
        parts = text.split(separator: ".").compactMap { Int($0) }
    }

    public var description: String { text }

    /// Whether two versions are the same, missing trailing numbers counting as zero.
    /// @example VersionNumber(parsing: "1.2")! == VersionNumber(parsing: "1.2.0")! // true
    public static func == (lhs: VersionNumber, rhs: VersionNumber) -> Bool {
        compare(lhs, rhs) == 0
    }

    /// Whether the left version is older than the right one.
    /// @example VersionNumber(parsing: "2.1.287")! < VersionNumber(parsing: "2.1.288")! // true
    public static func < (lhs: VersionNumber, rhs: VersionNumber) -> Bool {
        compare(lhs, rhs) < 0
    }

    /// Returns -1, 0 or 1, missing trailing numbers counting as zero.
    /// @example compare(VersionNumber(parsing: "1.2")!, VersionNumber(parsing: "1.2.0")!) // 0
    private static func compare(_ lhs: VersionNumber, _ rhs: VersionNumber) -> Int {
        for index in 0..<max(lhs.parts.count, rhs.parts.count) {
            let left = index < lhs.parts.count ? lhs.parts[index] : 0
            let right = index < rhs.parts.count ? rhs.parts[index] : 0
            if left != right { return left < right ? -1 : 1 }
        }
        return 0
    }
}
