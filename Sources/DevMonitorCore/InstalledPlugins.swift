import Foundation

/// Reads `~/.claude/plugins/installed_plugins.json`.
public enum InstalledPlugins {
    /// Returns every install record, in id order; none when the data is not that file.
    /// @example InstalledPlugins.plugins(from: data).map(\.pluginID) // ["figma@claude-plugins-official"]
    public static func plugins(from data: Data) -> [InstalledPlugin] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["plugins"] as? [String: Any]
        else { return [] }
        return entries.flatMap { key, value -> [InstalledPlugin] in
            guard let at = key.lastIndex(of: "@"), at != key.startIndex, let records = value as? [[String: Any]] else { return [] }
            let name = String(key[..<at])
            let marketplace = String(key[key.index(after: at)...])
            guard !marketplace.isEmpty else { return [] }
            return records.map { record in
                InstalledPlugin(
                    name: name, marketplace: marketplace, scope: record["scope"] as? String ?? "user",
                    version: record["version"] as? String, commitSHA: record["gitCommitSha"] as? String,
                    installPath: record["installPath"] as? String, projectPath: record["projectPath"] as? String)
            }
        }
        .sorted { $0.id < $1.id }
    }
}
