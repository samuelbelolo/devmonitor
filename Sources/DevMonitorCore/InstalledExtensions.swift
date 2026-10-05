import Foundation

/// The skills, plugins and marketplaces found on this Mac.
public struct InstalledExtensions: Sendable {
    public let skills: [InstalledSkill]
    public let plugins: [InstalledPlugin]
    public let marketplaces: [String: Marketplace]

    public init(skills: [InstalledSkill], plugins: [InstalledPlugin], marketplaces: [String: Marketplace]) {
        self.skills = skills
        self.plugins = plugins
        self.marketplaces = marketplaces
    }

    /// Reads the global skills lock file and Claude Code's plugin files under a home folder; a missing file reads as empty.
    /// @example InstalledExtensions.read().plugins.count // 22
    public static func read(
        home: String = NSHomeDirectory(),
        contents: (String) -> Data? = { FileManager.default.contents(atPath: $0) }
    ) -> InstalledExtensions {
        let plugins = home + "/.claude/plugins"
        return InstalledExtensions(
            skills: contents(home + "/.agents/.skill-lock.json").map(SkillLock.skills) ?? [],
            plugins: contents(plugins + "/installed_plugins.json").map(InstalledPlugins.plugins) ?? [],
            marketplaces: contents(plugins + "/known_marketplaces.json").map { Marketplaces.read(known: $0, contents: contents) } ?? [:])
    }

    /// The GitHub repositories the skills come from, each once.
    public var skillSources: [SkillSource] {
        Array(Set(skills.compactMap(\.gitHubSource)))
    }

    /// Builds the report; the plugin states read the marketplaces and the installs on disk, so call it off the main thread.
    /// @example installed.report(trees: trees, checksUpstream: true, now: Date()).staleCatalogs // 5
    public func report(trees: [SkillSource: RepoTree], checksUpstream: Bool, now: Date) -> ExtensionReport {
        ExtensionReport(
            skills: SkillSources.sources(for: skills, trees: trees, checksUpstream: checksUpstream),
            plugins: PluginSources.sources(for: plugins, marketplaces: marketplaces),
            staleCatalogs: PluginSources.staleCatalogs(for: plugins, marketplaces: marketplaces, now: now))
    }
}
