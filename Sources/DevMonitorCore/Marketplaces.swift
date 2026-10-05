import Foundation

/// Reads the marketplaces Claude Code knows: `known_marketplaces.json`, then each one's catalog on disk.
public enum Marketplaces {
    /// Returns the marketplaces by name; `contents` returns the bytes of the file at a path, nil when there is none.
    /// @example Marketplaces.read(known: data) { FileManager.default.contents(atPath: $0) }["brag"]?.location // "/Users/me/.claude/plugins/marketplaces/brag"
    public static func read(known data: Data, contents: (String) -> Data?) -> [String: Marketplace] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var marketplaces: [String: Marketplace] = [:]
        for (name, value) in json {
            guard let record = value as? [String: Any], let location = record["installLocation"] as? String else { continue }
            let catalog = contents(location + "/.claude-plugin/marketplace.json")
            marketplaces[name] = Marketplace(
                name: name, location: location, lastUpdated: (record["lastUpdated"] as? String).flatMap(date),
                entries: catalog.map(entries) ?? [:])
        }
        return marketplaces
    }

    /// Returns the plugins of a `marketplace.json`, by name.
    /// @example entries(from: catalog)["figma"]?.source // .pinned(sha: "1729…")
    private static func entries(from data: Data) -> [String: Marketplace.Entry] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let plugins = json["plugins"] as? [[String: Any]]
        else { return [:] }
        var entries: [String: Marketplace.Entry] = [:]
        for plugin in plugins {
            guard let name = plugin["name"] as? String else { continue }
            entries[name] = Marketplace.Entry(version: plugin["version"] as? String, source: source(from: plugin["source"]))
        }
        return entries
    }

    /// Reads a catalog `source`: a relative path, or an object that may name a commit.
    /// @example source(from: "./plugins/figma") // .relative(path: "plugins/figma")
    private static func source(from value: Any?) -> Marketplace.Source {
        if let path = value as? String {
            let parts = path.split(separator: "/").filter { $0 != "." }
            return parts.contains("..") ? .other : .relative(path: parts.joined(separator: "/"))
        }
        if let object = value as? [String: Any], let sha = object["sha"] as? String, !sha.isEmpty { return .pinned(sha: sha) }
        return .other
    }

    /// Reads a timestamp such as `2026-10-05T15:32:58.748Z`, with or without fractions of a second.
    /// @example date("2026-10-05T15:32:58.748Z") // 2026-10-05 15:32:58 +0000
    private static func date(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
}
