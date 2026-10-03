import Foundation

/// Groups services and containers by project.
public enum ProjectGrouper {
    /// Returns one group per project, heaviest first, with MCP servers in their own group at the end.
    /// @example ProjectGrouper.groups(services: services, containers: containers).map(\.name) // ["shop", "my-tool", "MCP servers"]
    public static func groups(services: [Service], containers: [DockerContainer]) -> [ProjectGroup] {
        let projectServices = Dictionary(grouping: services.filter { !$0.isMCP }, by: \.location.root)
        let projectContainers = Dictionary(grouping: containers, by: \.projectRoot)
        let roots = Set(projectServices.keys).union(projectContainers.keys)
        let projects = roots.map { root -> ProjectGroup in
            let services = heaviestFirst(projectServices[root] ?? [])
            let containers = projectContainers[root] ?? []
            let name = services.first?.location.name ?? containers.first?.projectName ?? root
            return ProjectGroup(id: root, kind: .project, name: name, services: services, containers: containers)
        }.sorted { MemoryRank.key($0.memoryBytes, $0.name) < MemoryRank.key($1.memoryBytes, $1.name) }
        let mcp = heaviestFirst(services.filter(\.isMCP))
        // Project ids are absolute paths, so this id cannot collide with one; the interface gives the group its own title.
        return projects + (mcp.isEmpty ? [] : [ProjectGroup(id: "mcp-servers", kind: .mcpServers, name: "MCP servers", services: mcp, containers: [])])
    }

    /// Sorts services heaviest first, in the stable order of `MemoryRank`.
    /// @example heaviestFirst([small, big]).first // big
    private static func heaviestFirst(_ services: [Service]) -> [Service] {
        services.sorted { MemoryRank.key($0.memoryBytes, $0.id) < MemoryRank.key($1.memoryBytes, $1.id) }
    }
}
