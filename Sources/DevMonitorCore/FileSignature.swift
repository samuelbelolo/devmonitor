import Foundation

/// What tells one version of a file from the next without reading it: a rewrite in place moves its date or its size,
/// a replacement gives it another file number.
struct FileSignature: Equatable {
    let modified: Date?
    let size: UInt64?
    let fileNumber: UInt64?

    /// Returns the signature of each file that exists, by its path; a missing file has none.
    /// @example FileSignature.of(["/Users/me/.agents/.skill-lock.json"]).count // 1
    static func of(_ files: Set<String>) -> [String: FileSignature] {
        var signatures: [String: FileSignature] = [:]
        for file in files {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: file) else { continue }
            signatures[file] = FileSignature(
                modified: attributes[.modificationDate] as? Date,
                size: (attributes[.size] as? NSNumber)?.uint64Value,
                fileNumber: (attributes[.systemFileNumber] as? NSNumber)?.uint64Value)
        }
        return signatures
    }
}
