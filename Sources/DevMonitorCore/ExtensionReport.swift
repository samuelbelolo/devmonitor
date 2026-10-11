/// What the Extensions section shows: the skills and the plugins, each grouped by source.
public struct ExtensionReport: Sendable, Equatable {
    public let skills: [ExtensionSource]
    public let plugins: [ExtensionSource]
    /// How many marketplaces with an installed plugin were last refreshed more than seven days ago.
    public let staleCatalogs: Int

    public init(skills: [ExtensionSource], plugins: [ExtensionSource], staleCatalogs: Int) {
        self.skills = skills
        self.plugins = plugins
        self.staleCatalogs = staleCatalogs
    }

    public static let empty = ExtensionReport(skills: [], plugins: [], staleCatalogs: 0)
    public var isEmpty: Bool { skills.isEmpty && plugins.isEmpty }

    /// The command that updates every skill and plugin with an update, when it replaces more than one command: the
    /// `skills` tool takes the names of skills from several repositories at once, while each plugin has its own.
    public var updateAll: UpdateAll? {
        let skillNames = skills.flatMap(\.outdated).map(\.name)
        let pluginCommands = plugins.flatMap(\.outdated).compactMap(\.command)
        guard skills.compactMap(\.command).count + pluginCommands.count > 1 else { return nil }
        // An outdated skill always has a name safe to paste: SkillSources reads the others as unknown.
        let skillCommand = ExtensionCommand.updateSkills(skillNames).map { [$0] } ?? []
        // Each command runs whatever the previous one gave, so one failure does not stop the others.
        return UpdateAll(command: (skillCommand + pluginCommands).joined(separator: "; "), skills: skillNames.count, plugins: pluginCommands.count)
    }

    /// Returns how many items of these sources have an update.
    /// @example ExtensionReport.updates(in: report.skills) // 27
    public static func updates(in sources: [ExtensionSource]) -> Int {
        sources.reduce(0) { $0 + $1.updates }
    }

    /// Returns how many items these sources hold.
    /// @example ExtensionReport.count(in: report.plugins) // 22
    public static func count(in sources: [ExtensionSource]) -> Int {
        sources.reduce(0) { $0 + $1.items.count }
    }
}
