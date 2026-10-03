import Foundation

/// Attaches Compose containers to the project their Compose file lives in.
public enum ContainerLocator {
    /// Returns the containers started from a project, moved to the main checkout of their repository;
    /// a stack started from anywhere else is left out, like a process outside any project.
    /// @example ContainerLocator.locate(containers, resolver: resolver).map(\.projectName) // ["shop", "shop"]
    public static func locate(_ containers: [DockerContainer], resolver: RepoResolver) -> [DockerContainer] {
        containers.compactMap { container in
            guard let location = resolver.resolve(container.projectRoot) else { return nil }
            var located = container
            located.projectRoot = location.root
            located.projectName = location.name
            return located
        }
    }
}
