import Foundation

/// The skills, plugins and marketplaces found on this Mac.
public struct InstalledExtensions: Sendable {
    public let skills: [InstalledSkill]
    public let plugins: [InstalledPlugin]
    public let marketplaces: [String: Marketplace]
    /// False when the skills lock file exists but is not one, as while the `skills` tool rewrites it in place.
    public let isSkillLockReadable: Bool

    public init(skills: [InstalledSkill], plugins: [InstalledPlugin], marketplaces: [String: Marketplace], isSkillLockReadable: Bool) {
        self.skills = skills
        self.plugins = plugins
        self.marketplaces = marketplaces
        self.isSkillLockReadable = isSkillLockReadable
    }

    /// The files read, by path from the home folder.
    private static let skillLockFile = ".agents/.skill-lock.json"
    private static let installedPluginsFile = ".claude/plugins/installed_plugins.json"
    private static let knownMarketplacesFile = ".claude/plugins/known_marketplaces.json"
    /// The files whose change can change what is installed, by path from the home folder.
    public static let watchedFiles = [skillLockFile, installedPluginsFile, knownMarketplacesFile]

    /// Reads the global skills lock file and Claude Code's plugin files under a home folder; a missing file reads as
    /// empty, and so does a skills lock file that is not one, with `isSkillLockReadable` false.
    /// @example InstalledExtensions.read().plugins.count // 22
    public static func read(
        home: String = NSHomeDirectory(),
        contents: (String) -> Data? = { FileManager.default.contents(atPath: $0) }
    ) -> InstalledExtensions {
        let lock = contents(home + "/" + skillLockFile)
        let skills = lock.flatMap(SkillLock.skills)
        return InstalledExtensions(
            skills: skills ?? [],
            plugins: contents(home + "/" + installedPluginsFile).map(InstalledPlugins.plugins) ?? [],
            marketplaces: contents(home + "/" + knownMarketplacesFile).map { Marketplaces.read(known: $0, contents: contents) } ?? [:],
            isSkillLockReadable: lock == nil || skills != nil)
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
