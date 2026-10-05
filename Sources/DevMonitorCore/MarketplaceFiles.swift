import Foundation

/// Reads what a marketplace on disk says about one of its own plugins: its declared version, and its files.
public enum MarketplaceFiles {
    /// Returns the version in the manifest of a plugin folder, `<folder>/.claude-plugin/plugin.json`; nil when it declares none.
    /// @example MarketplaceFiles.declaredVersion(in: "/m/official/plugins/security-guidance") // "2.0.9"
    public static func declaredVersion(in folder: String) -> String? {
        guard let data = FileManager.default.contents(atPath: folder + "/.claude-plugin/plugin.json"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json["version"] as? String
    }

    /// Entries Claude Code or a tool adds beside a plugin's files, which say nothing about its content.
    private static let bookkeeping: Set<String> = [".in_use", ".orphaned_at", ".git", ".gcs-sha", ".DS_Store", "__pycache__"]

    /// What a path is, with enough to tell two entries apart before reading any file.
    private enum Entry: Equatable {
        case folder
        case file(size: UInt64)
        case link(to: String)
    }

    /// Whether two folders hold the same files with the same content, bookkeeping entries aside and symbolic links
    /// compared by their target; nil when one of them is not a folder.
    /// @example MarketplaceFiles.sameFiles("/cache/official/feature-dev/d4226d0", "/m/official/plugins/feature-dev") // true
    public static func sameFiles(_ first: String, _ second: String) -> Bool? {
        guard let left = listing(of: first), let right = listing(of: second) else { return nil }
        guard left == right else { return false }
        return left.allSatisfy { path, entry in
            guard case .file = entry else { return true }
            return FileManager.default.contentsEqual(atPath: first + "/" + path, andPath: second + "/" + path)
        }
    }

    /// Returns every entry under a folder by its relative path, without following symbolic links; nil when it is not a folder.
    /// @example listing(of: "/m/official/plugins/feature-dev")?["README.md"] // .file(size: 11_400)
    private static func listing(of root: String) -> [String: Entry]? {
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root, isDirectory: &isFolder), isFolder.boolValue,
              let walker = FileManager.default.enumerator(atPath: root)
        else { return nil }
        var entries: [String: Entry] = [:]
        while let path = walker.nextObject() as? String {
            if bookkeeping.contains((path as NSString).lastPathComponent) {
                walker.skipDescendants()
                continue
            }
            let attributes = walker.fileAttributes
            switch attributes?[.type] as? FileAttributeType {
            case .typeDirectory: entries[path] = .folder
            case .typeSymbolicLink: entries[path] = .link(to: (try? FileManager.default.destinationOfSymbolicLink(atPath: root + "/" + path)) ?? "")
            default: entries[path] = .file(size: (attributes?[.size] as? NSNumber)?.uint64Value ?? 0)
            }
        }
        return entries
    }
}
