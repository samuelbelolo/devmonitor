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
