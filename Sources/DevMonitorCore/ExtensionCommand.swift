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

    /// Returns the command that updates one install of a plugin; nil when its id or scope is not safe to paste.
    /// The scope is always written: without it, the tool picks one from the folder the command runs in.
    /// @example ExtensionCommand.updatePlugin(plugin) // "claude plugin update figma@claude-plugins-official --scope user"
    public static func updatePlugin(_ plugin: InstalledPlugin) -> String? {
        guard isPlainWord(plugin.pluginID), isPlainWord(plugin.scope) else { return nil }
        return "claude plugin update \(plugin.pluginID) --scope \(plugin.scope)"
    }

    /// Whether a text is one shell word with no special character, and not an option.
    /// @example ExtensionCommand.isPlainWord("-g") // false
    public static func isPlainWord(_ text: String) -> Bool {
        text.range(of: "^[A-Za-z0-9@][A-Za-z0-9._@/-]*$", options: .regularExpression) != nil
    }
}
