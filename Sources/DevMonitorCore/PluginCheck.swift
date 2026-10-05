import Foundation

/// Compares an installed plugin with the catalog of its marketplace on disk. No network: the answer is as fresh
/// as the marketplace's last refresh.
public enum PluginCheck {
    /// Returns the state of a plugin; `declaredVersion` reads the manifest of a plugin folder and `sameFiles`
    /// compares two folders.
    /// @example PluginCheck.state(of: plugin, in: marketplaces[plugin.marketplace]) // .updateAvailable
    public static func state(
        of plugin: InstalledPlugin, in marketplace: Marketplace?,
        declaredVersion: (_ folder: String) -> String? = MarketplaceFiles.declaredVersion(in:),
        sameFiles: (_ installed: String, _ published: String) -> Bool? = MarketplaceFiles.sameFiles
    ) -> ExtensionState {
        guard let marketplace, let entry = marketplace.entries[plugin.name] else { return .unknown(.noCatalog) }
        switch entry.source {
        case .pinned(let sha):
            // Claude Code updates on a new version, not on a new commit: the catalog's version decides when it gives one.
            if let published = entry.version, let installed = plugin.version { return published == installed ? .upToDate : .updateAvailable }
            guard let installed = plugin.commitSHA else { return .unknown(.nothingToCompare) }
            return installed == sha ? .upToDate : .updateAvailable
        case .relative(let path):
            let published = marketplace.folder(of: path)
            // The plugin's own manifest wins over the catalog, as it does when Claude Code computes the version.
            if let version = declaredVersion(published) ?? entry.version, let installed = plugin.version {
                return version == installed ? .upToDate : .updateAvailable
            }
            // No version to compare: the plugin is up to date when its installed files are the marketplace's.
            guard let installed = plugin.installPath, let same = sameFiles(installed, published) else { return .unknown(.nothingToCompare) }
            return same ? .upToDate : .updateAvailable
        case .other:
            return .unknown(.nothingToCompare)
        }
    }
}
