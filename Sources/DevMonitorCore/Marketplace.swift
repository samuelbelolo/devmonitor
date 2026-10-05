import Foundation

/// A plugin marketplace as it is on disk: where it is, when it was last refreshed, and its catalog.
public struct Marketplace: Sendable, Equatable {
    /// One plugin of the catalog.
    public struct Entry: Sendable, Equatable {
        public let version: String?
        public let source: Source

        public init(version: String?, source: Source) {
            self.version = version
            self.source = source
        }
    }

    /// Where the catalog says a plugin's files are.
    public enum Source: Sendable, Equatable {
        /// Another repository, at a commit the catalog names.
        case pinned(sha: String)
        /// A folder of the marketplace itself, from its root; empty for the root.
        case relative(path: String)
        /// A source the catalog does not pin to a commit.
        case other
    }

    public let name: String
    public let location: String
    public let lastUpdated: Date?
    /// The catalog, by plugin name; empty when the catalog file is missing.
    public let entries: [String: Entry]

    /// Returns the folder of a plugin whose catalog source is a path relative to the marketplace, empty for its root.
    /// @example marketplace.folder(of: "plugins/figma") // "/m/official/plugins/figma"
    public func folder(of path: String) -> String {
        path.isEmpty ? location : location + "/" + path
    }

    public init(name: String, location: String, lastUpdated: Date?, entries: [String: Entry]) {
        self.name = name
        self.location = location
        self.lastUpdated = lastUpdated
        self.entries = entries
    }
}
