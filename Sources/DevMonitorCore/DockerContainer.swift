import Foundation

/// A running container that belongs to a Compose project.
public struct DockerContainer: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    /// The Compose working directory, resolved to its project root.
    public var projectRoot: String
    public var projectName: String
    public var memoryBytes: UInt64

    public init(id: String, name: String, projectRoot: String, projectName: String, memoryBytes: UInt64) {
        self.id = id
        self.name = name
        self.projectRoot = projectRoot
        self.projectName = projectName
        self.memoryBytes = memoryBytes
    }
}
