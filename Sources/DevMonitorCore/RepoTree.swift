import Foundation

/// The folders of a repository at one commit, each with its git tree hash, as GitHub's trees API lists them.
public struct RepoTree: Sendable, Equatable {
    public let rootSHA: String
    /// The tree hash of every folder, by its path from the root.
    public let folders: [String: String]
    /// Whether GitHub cut the list short: a folder missing from it may still exist.
    public let isTruncated: Bool

    public init(rootSHA: String, folders: [String: String], isTruncated: Bool) {
        self.rootSHA = rootSHA
        self.folders = folders
        self.isTruncated = isTruncated
    }

    /// Reads the answer of `GET /repos/<owner>/<repo>/git/trees/<ref>?recursive=1`; nil when it is anything else.
    /// @example RepoTree(parsing: answer)?.folderSHA("skills/audit") // "a1"
    public init?(parsing data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sha = json["sha"] as? String, let entries = json["tree"] as? [[String: Any]]
        else { return nil }
        var folders: [String: String] = [:]
        for entry in entries where entry["type"] as? String == "tree" {
            if let path = entry["path"] as? String, let sha = entry["sha"] as? String { folders[path] = sha }
        }
        self.init(rootSHA: sha, folders: folders, isTruncated: json["truncated"] as? Bool ?? false)
    }

    /// Returns the tree hash of a folder, the empty path being the root; nil when there is no such folder.
    /// @example tree.folderSHA("") // "root1"
    public func folderSHA(_ folder: String) -> String? {
        folder.isEmpty ? rootSHA : folders[folder]
    }
}
