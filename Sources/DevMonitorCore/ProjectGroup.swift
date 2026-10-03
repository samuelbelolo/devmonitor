import Foundation

/// Everything that runs for one project: its services and its Compose containers.
public struct ProjectGroup: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case project
        /// The MCP servers and other tools of every agent session, whatever project they were started in.
        case mcpServers
    }

    public let id: String
    public let kind: Kind
    public let name: String
    public let services: [Service]
    public let containers: [DockerContainer]

    public var memoryBytes: UInt64 {
        services.reduce(0) { $0 + $1.memoryBytes } + containers.reduce(0) { $0 + $1.memoryBytes }
    }
    /// The lines to show: one per service, except MCP servers, which are merged by label.
    public var rows: [ServiceRow] {
        guard kind == .mcpServers else { return services.map { ServiceRow(label: $0.label, services: [$0]) } }
        return Dictionary(grouping: services, by: \.label)
            .map { ServiceRow(label: $0.key, services: $0.value) }
            .sorted { MemoryRank.key($0.memoryBytes, $0.label) < MemoryRank.key($1.memoryBytes, $1.label) }
    }

    public var processCount: Int { services.reduce(0) { $0 + $1.members.count } }
}
