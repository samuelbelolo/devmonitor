import Foundation

/// Where a process runs inside a project.
public struct ProjectLocation: Equatable, Sendable {
    /// The main checkout of the repository (shared by all its worktrees), or the package directory.
    public let root: String
    public let name: String
    /// The worktree directory name, nil in the main checkout.
    public let worktree: String?
    /// The path of the nearest package below the worktree root, e.g. "packages/ui".
    public let package: String?

    public init(root: String, name: String, worktree: String?, package: String?) {
        self.root = root
        self.name = name
        self.worktree = worktree
        self.package = package
    }
}
