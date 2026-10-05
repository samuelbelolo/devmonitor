import Foundation

/// Groups the installed plugins by marketplace.
public enum PluginSources {
    /// A catalog older than this may hide updates.
    private static let staleAfter: TimeInterval = 7 * 86_400

    /// Returns one source per marketplace, in display order; `state` compares a plugin with its marketplace.
    /// @example PluginSources.sources(for: plugins, marketplaces: marketplaces).first?.name // "claude-plugins-official"
    public static func sources(
        for plugins: [InstalledPlugin], marketplaces: [String: Marketplace],
        state: (InstalledPlugin, Marketplace?) -> ExtensionState = { PluginCheck.state(of: $0, in: $1) }
    ) -> [ExtensionSource] {
        let sources = Dictionary(grouping: plugins, by: \.marketplace).map { name, members -> ExtensionSource in
            let items = members.sorted { $0.id < $1.id }.map { item(for: $0, state: state($0, marketplaces[name])) }
            return ExtensionSource(kind: .plugins, name: name, items: items, command: nil)
        }
        return ExtensionSource.inDisplayOrder(sources)
    }

    /// Returns the line of one install: its version, its scope and project when it is not a user install, and its
    /// command when it has an update. An update whose id cannot go into a command reads as unknown, with that reason.
    /// @example item(for: plugin, state: .updateAvailable).command // "claude plugin update figma@official --scope user"
    private static func item(for plugin: InstalledPlugin, state: ExtensionState) -> ExtensionItem {
        let command = state == .updateAvailable ? ExtensionCommand.updatePlugin(plugin) : nil
        let project = plugin.projectPath.map { ($0 as NSString).lastPathComponent }
        let detail = [plugin.version, plugin.scope == "user" ? nil : plugin.scope, project].compactMap { $0 }.joined(separator: " · ")
        return ExtensionItem(
            id: plugin.id, name: plugin.name, detail: detail.isEmpty ? nil : detail,
            state: state == .updateAvailable && command == nil ? .unknown(.unsafeName) : state, command: command)
    }

    /// Returns how many marketplaces with an installed plugin were last refreshed more than seven days before `now`.
    /// @example PluginSources.staleCatalogs(for: plugins, marketplaces: marketplaces, now: Date()) // 5
    public static func staleCatalogs(for plugins: [InstalledPlugin], marketplaces: [String: Marketplace], now: Date) -> Int {
        Set(plugins.map(\.marketplace)).filter { name in
            guard let refreshed = marketplaces[name]?.lastUpdated else { return false }
            return now.timeIntervalSince(refreshed) > staleAfter
        }.count
    }
}
