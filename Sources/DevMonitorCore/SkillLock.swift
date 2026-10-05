import Foundation

/// Reads `~/.agents/.skill-lock.json`, where the `skills` tool records what it installed globally.
public enum SkillLock {
    /// Returns the skills of a lock file in name order; none when the data is not a lock file.
    /// @example SkillLock.skills(from: lockData).map(\.name) // ["audit", "find-skills"]
    public static func skills(from data: Data) -> [InstalledSkill] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["skills"] as? [String: Any]
        else { return [] }
        return entries.compactMap { name, value -> InstalledSkill? in
            guard let entry = value as? [String: Any] else { return nil }
            return InstalledSkill(
                name: name, source: text(entry["source"]), sourceType: text(entry["sourceType"]), ref: text(entry["ref"]),
                skillPath: text(entry["skillPath"]), folderHash: text(entry["skillFolderHash"]))
        }
        .sorted { $0.name < $1.name }
    }

    /// Returns a JSON value as text, nil when it is not a string or is empty.
    /// @example text("") // nil
    private static func text(_ value: Any?) -> String? {
        guard let string = value as? String, !string.isEmpty else { return nil }
        return string
    }
}
