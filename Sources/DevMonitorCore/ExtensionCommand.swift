import Foundation

/// The commands that update skills and plugins. The names come from files any tool can write and the user pastes
/// the command into a shell, so a name that is not a plain word never reaches a command.
public enum ExtensionCommand {
    /// Refreshes every marketplace from its source.
    public static let refreshMarketplaces = "claude plugin marketplace update"

    /// Returns the command that updates these global skills; nil when no name is safe to paste.
    /// @example ExtensionCommand.updateSkills(["audit", "find-skills"]) // "npx skills update audit find-skills -g -y"
    public static func updateSkills(_ names: [String]) -> String? {
        let safe = names.filter(isPlainWord)
        return safe.isEmpty ? nil : "npx skills update \(safe.joined(separator: " ")) -g -y"
    }

    /// Returns the command that updates one install of a plugin; nil when its id, scope or project is not safe to
    /// paste. The scope is always written: without it, the tool picks one from the folder the command runs in. An
    /// install that belongs to a project is updated from that project, in a subshell so the terminal stays where it is.
    /// @example ExtensionCommand.updatePlugin(plugin) // "claude plugin update figma@claude-plugins-official --scope user"
    public static func updatePlugin(_ plugin: InstalledPlugin) -> String? {
        guard isPlainWord(plugin.pluginID), isPlainWord(plugin.scope) else { return nil }
        let update = "claude plugin update \(plugin.pluginID) --scope \(plugin.scope)"
        guard let project = plugin.projectPath else { return update }
        guard let folder = quoted(project) else { return nil }
        return "(cd \(folder) && \(update))"
    }

    /// Returns a text in single quotes for the shell, each quote it holds written `'\''`; nil when it holds a
    /// control character, which a pasted line would run or hide.
    /// @example ExtensionCommand.quoted("/Users/me/it's") // "'/Users/me/it'\''s'"
    public static func quoted(_ text: String) -> String? {
        guard !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        return "'" + text.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }

    /// Whether a text is one shell word with no special character, and not an option.
    /// @example ExtensionCommand.isPlainWord("-g") // false
    public static func isPlainWord(_ text: String) -> Bool {
        text.range(of: "^[A-Za-z0-9@][A-Za-z0-9._@/-]*$", options: .regularExpression) != nil
    }
}
