import Foundation

/// Turns a process tree into the services worth showing.
public struct ServiceBuilder {
    private typealias Roles = [Int32: ProcessRole]

    private let resolver: RepoResolver
    /// Seconds a process must have lived before it is listed, so one-off commands never flash by.
    public static let minimumAge: UInt64 = 20

    public init(resolver: RepoResolver) {
        self.resolver = resolver
    }

    /// Returns one service per process tree that runs inside a project, skipping apps, agents, shells and what wraps them.
    /// @example builder.services(in: tree, now: 1_700_000_060).map(\.label) // ["pnpm dev", "serena start-mcp-server"]
    public func services(in tree: ProcessTree, now: UInt64 = UInt64(Date().timeIntervalSince1970)) -> [Service] {
        let roles = Dictionary(tree.snapshots.map { ($0.pid, ProcessRole.of($0)) }, uniquingKeysWith: { first, _ in first })
        return tree.snapshots
            .filter { $0.startTime + Self.minimumAge <= now && isRoot($0, in: tree, roles: roles) }
            .compactMap { service(root: $0, in: tree, roles: roles) }
    }

    /// Whether a process starts a service: a regular process that no other regular process owns,
    /// and that does not wrap an agent session or a shell someone types in.
    /// @example isRoot(pnpm, in: tree, roles: roles) // true when its parent is the shell an agent spawned
    private func isRoot(_ process: ProcessSnapshot, in tree: ProcessTree, roles: Roles) -> Bool {
        guard roles[process.pid] == .regular else { return false }
        let ancestors = tree.ancestors(of: process.pid)
        // A direct child of an app is one of its helpers (a language server), not something the user started.
        if let parent = ancestors.first, roles[parent.pid] == .protected { return false }
        let owner = ancestors.first { roles[$0.pid] != .wrapperShell }
        if let owner, roles[owner.pid] == .regular { return false }
        // Stopping a wrapper would end the session it holds, so a wrapper is never a service.
        return !tree.descendants(of: process.pid).contains { holdsASession(roles[$0.pid]) }
    }

    /// Whether a role is a session the monitor must leave running: an agent or an interactive shell.
    /// @example holdsASession(.interactiveShell) // true
    private func holdsASession(_ role: ProcessRole?) -> Bool {
        if case .agent = role { return true }
        return role == .interactiveShell
    }

    /// Builds the service rooted at a process, or nil when it runs outside any project.
    /// @example service(root: pnpm, in: tree, roles: roles)?.members.count // 2
    private func service(root: ProcessSnapshot, in tree: ProcessTree, roles: Roles) -> Service? {
        let members = members(of: root, in: tree, roles: roles)
        let ancestors = tree.ancestors(of: root.pid)
        let directories = (members + ancestors).compactMap(\.workingDirectory)
        guard let location = directories.lazy.compactMap({ self.resolver.resolve($0) }).first else { return nil }
        let agents = ancestors.compactMap { ancestor -> Agent? in
            if case .agent(let agent) = roles[ancestor.pid] { return agent }
            return nil
        }
        // What an agent starts without a shell is one of its own tools; what it runs for the user goes through a shell.
        let isAgentTool = ancestors.first.map { holdsAnAgent(roles[$0.pid]) } ?? false
        return Service(
            root: root, members: members, label: ServiceLabel.of(root), location: location, agent: agents.first,
            isMCP: isAgentTool || McpCommand.matches(members.flatMap(\.arguments)))
    }

    /// Whether a role is an agent session.
    /// @example holdsAnAgent(.agent(.claude)) // true
    private func holdsAnAgent(_ role: ProcessRole?) -> Bool {
        if case .agent = role { return true }
        return false
    }

    /// Returns a root and the processes it owns, parents before children: wrapper shells and regular processes,
    /// never past an app, an agent or an interactive shell.
    /// @example members(of: pnpm, in: tree, roles: roles).map(\.pid) // [40, 50]
    private func members(of root: ProcessSnapshot, in tree: ProcessTree, roles: Roles) -> [ProcessSnapshot] {
        var result: [ProcessSnapshot] = []
        var seen: Set<Int32> = []
        var pending = [root]
        while let next = pending.popLast() {
            guard seen.insert(next.pid).inserted else { continue }
            result.append(next)
            pending.append(contentsOf: tree.children(of: next.pid).filter { roles[$0.pid]?.isCandidate == true }.reversed())
        }
        return result
    }
}
