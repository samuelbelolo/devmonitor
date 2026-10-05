/// One install of a Claude Code plugin, as `installed_plugins.json` records it.
public struct InstalledPlugin: Sendable, Equatable, Identifiable {
    public let name: String
    public let marketplace: String
    /// Where it is installed: `user`, `project`, `local` or `managed`.
    public let scope: String
    public let version: String?
    /// The commit of the plugin's source when it was installed or last updated.
    public let commitSHA: String?
    /// The folder holding this install's copy of the plugin's files.
    public let installPath: String?
    /// The project a `project` or `local` install belongs to: its update command only works from there.
    public let projectPath: String?

    public init(name: String, marketplace: String, scope: String, version: String?, commitSHA: String?, installPath: String? = nil, projectPath: String? = nil) {
        self.name = name
        self.marketplace = marketplace
        self.scope = scope
        self.version = version
        self.commitSHA = commitSHA
        self.installPath = installPath
        self.projectPath = projectPath
    }

    /// The name the `claude plugin` commands take.
    public var pluginID: String { "\(name)@\(marketplace)" }
    /// One plugin can be installed once per scope, and once per project in the `project` and `local` scopes.
    public var id: String { [pluginID, scope, projectPath].compactMap { $0 }.joined(separator: " ") }
}
