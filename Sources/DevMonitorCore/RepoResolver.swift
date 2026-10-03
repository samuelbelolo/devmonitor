import Foundation

/// Maps a working directory to its project, remembering the directories already found.
public final class RepoResolver {
    private let home: String
    private let files = FileManager.default
    private var cache: [String: ProjectLocation] = [:]
    private static let manifests = ["package.json", "pyproject.toml", "Cargo.toml", "go.mod"]
    /// The most the resolver reads of a `.git` pointer and of a manifest; a larger file is not what it claims to be.
    private static let pointerLimit = 4_096
    private static let manifestLimit = 65_536

    public init(home: String = NSHomeDirectory()) {
        self.home = home
    }

    /// Returns the project a directory belongs to, or nil outside the home folder or outside any project.
    /// Only hits are remembered, so a folder that becomes a project later is found on the next call.
    /// @example resolver.resolve("/Users/me/acme/worktrees/feat-123/packages/ui")
    /// // ProjectLocation(root: "/Users/me/acme/shop", name: "shop", worktree: "feat-123", package: "packages/ui")
    public func resolve(_ directory: String) -> ProjectLocation? {
        let directory = Self.standardized(directory)
        if let hit = cache[directory] { return hit }
        guard let location = locate(directory) else { return nil }
        cache[directory] = location
        return location
    }

    /// Forgets every remembered directory, so removed checkouts and new repositories are seen again.
    /// @example resolver.clearCache()
    public func clearCache() {
        cache.removeAll()
    }

    /// Returns an absolute path without `.` and `..` components, leaving symbolic links alone.
    /// @example standardized("/Users/me/a/../b") // "/Users/me/b"
    private static func standardized(_ path: String) -> String {
        var parts: [Substring] = []
        for part in path.split(separator: "/") where part != "." {
            if part == ".." { _ = parts.popLast() } else { parts.append(part) }
        }
        return "/" + parts.joined(separator: "/")
    }

    /// Returns the directories from `directory` up to, but excluding, the home folder.
    /// @example parents(of: "/Users/me/a/b") // ["/Users/me/a/b", "/Users/me/a"]
    private func parents(of directory: String) -> [String] {
        guard directory.hasPrefix(home + "/") else { return [] }
        var result: [String] = []
        var current = directory
        while current != home, current.count > home.count {
            result.append(current)
            current = (current as NSString).deletingLastPathComponent
        }
        return result
    }

    /// Finds the git checkout or, failing that, the nearest manifest above a directory.
    /// @example locate("/Users/me/tools/my-tool/app")?.name // "my-tool"
    private func locate(_ directory: String) -> ProjectLocation? {
        let chain = parents(of: directory)
        if let checkout = chain.first(where: { files.fileExists(atPath: $0 + "/.git") }) {
            let root = mainCheckout(of: checkout)
            return ProjectLocation(
                root: root, name: DisplayText.clean(repositoryName(of: root)),
                worktree: root == checkout ? nil : DisplayText.clean((checkout as NSString).lastPathComponent),
                package: package(below: checkout, containing: directory).map { DisplayText.clean($0) })
        }
        guard let packageRoot = chain.first(where: hasManifest) else { return nil }
        return ProjectLocation(root: packageRoot, name: DisplayText.clean(manifestName(in: packageRoot)), worktree: nil, package: nil)
    }

    /// Returns the folder that stands for the whole repository of a worktree, or the checkout itself when it is
    /// the main one. The `.git` pointer may be relative, and may lead to a bare repository.
    /// @example mainCheckout(of: "/Users/me/acme/worktrees/feat-123") // "/Users/me/acme/shop"
    private func mainCheckout(of checkout: String) -> String {
        guard let data = start(of: checkout + "/.git", limit: Self.pointerLimit) else { return checkout }
        let pointer = String(decoding: data, as: UTF8.self)
        guard pointer.hasPrefix("gitdir:"), let line = pointer.dropFirst("gitdir:".count).split(separator: "\n").first else { return checkout }
        let target = line.trimmingCharacters(in: .whitespaces)
        let gitDirectory = Self.standardized(target.hasPrefix("/") ? target : checkout + "/" + target)
        guard let marker = gitDirectory.range(of: "/worktrees/", options: .backwards) else { return checkout }
        let common = String(gitDirectory[..<marker.lowerBound])
        // `.git`, or a hidden bare folder such as `.bare`, sits inside the folder that names the repository.
        let root = (common as NSString).lastPathComponent.hasPrefix(".") ? (common as NSString).deletingLastPathComponent : common
        var isDirectory: ObjCBool = false
        let isUsable = root.hasPrefix(home + "/") && files.fileExists(atPath: root, isDirectory: &isDirectory) && isDirectory.boolValue
        return isUsable ? root : checkout
    }

    /// Returns the name of a repository from its folder, without the `.git` suffix of a bare one.
    /// @example repositoryName(of: "/Users/me/acme/api.git") // "api"
    private func repositoryName(of root: String) -> String {
        let folder = (root as NSString).lastPathComponent
        return folder.hasSuffix(".git") && folder.count > 4 ? String(folder.dropLast(4)) : folder
    }

    /// Returns the path of the nearest package strictly below the checkout root, if any.
    /// @example package(below: "/r", containing: "/r/packages/ui/src") // "packages/ui"
    private func package(below checkout: String, containing directory: String) -> String? {
        var current = directory
        while current != checkout, current.count > checkout.count {
            if hasManifest(current) { return String(current.dropFirst(checkout.count + 1)) }
            current = (current as NSString).deletingLastPathComponent
        }
        return nil
    }

    /// Whether a directory holds a package manifest.
    /// @example hasManifest("/Users/me/tools/my-tool/app") // true
    private func hasManifest(_ directory: String) -> Bool {
        Self.manifests.contains { files.fileExists(atPath: directory + "/" + $0) }
    }

    /// Returns the "name" of a package.json, or the directory name.
    /// @example manifestName(in: "/Users/me/tools/my-tool/app") // "my-tool"
    private func manifestName(in directory: String) -> String {
        let fallback = (directory as NSString).lastPathComponent
        guard let data = start(of: directory + "/package.json", limit: Self.manifestLimit),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String, !name.isEmpty
        else { return fallback }
        return name
    }

    /// Returns the first bytes of a regular file, or nil for anything else: a folder, a pipe, a device.
    /// @example start(of: "/Users/me/acme/worktrees/feat-123/.git", limit: 4_096) // "gitdir: …" as data
    private func start(of path: String, limit: Int) -> Data? {
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true,
              let handle = try? FileHandle(forReadingFrom: url)
        else { return nil }
        defer { try? handle.close() }
        return try? handle.read(upToCount: limit)
    }
}
