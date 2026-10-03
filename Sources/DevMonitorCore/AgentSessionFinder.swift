import Foundation

/// Finds the coding agent sessions among the processes of a scan.
public enum AgentSessionFinder {
    /// Returns one session per agent process that no other agent process started, in pid order.
    /// An agent an agent runs (`codex exec` from Claude) and the process a wrapper starts belong to the outer session.
    /// @example AgentSessionFinder.sessions(in: tree, resolver: resolver).map(\.agent) // [.claude, .claude, .codex]
    public static func sessions(in tree: ProcessTree, resolver: RepoResolver) -> [AgentSession] {
        tree.snapshots.sorted { $0.pid < $1.pid }.compactMap { process in
            guard let agent = agent(of: process) else { return nil }
            let ancestors = tree.ancestors(of: process.pid)
            guard !ancestors.contains(where: { self.agent(of: $0) != nil }) else { return nil }
            let directories = ([process] + ancestors).compactMap(\.workingDirectory)
            let cpuTimeNs = tree.descendants(of: process.pid)
                .filter { self.agent(of: $0) == agent }
                .reduce(process.cpuTimeNs) { $0 &+ $1.cpuTimeNs }
            return AgentSession(agent: agent, process: process, location: directories.lazy.compactMap { resolver.resolve($0) }.first, cpuTimeNs: cpuTimeNs)
        }
    }

    /// Returns the agent a process is a session of, if any. The agent's binary also runs tools under their own
    /// name (Claude Code runs `ugrep` that way): their first argument then names neither the agent nor the
    /// executable. An interpreter's first argument is its own name, so it is never taken for a tool.
    /// @example agent(of: claudeProcess) // .claude
    private static func agent(of process: ProcessSnapshot) -> Agent? {
        guard case .agent(let agent) = ProcessRole.of(process) else { return nil }
        let argv0 = ((process.arguments.first ?? "") as NSString).lastPathComponent
        let runsAsATool = !argv0.isEmpty && argv0 != agent.command && argv0 != process.name && !Agent.interprets(process)
        return runsAsATool ? nil : agent
    }
}
