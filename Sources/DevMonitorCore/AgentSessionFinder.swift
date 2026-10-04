import Foundation

/// Finds the coding agent sessions among the processes of a scan.
public enum AgentSessionFinder {
    /// Returns the sessions among the processes, in pid order. An agent process an agent starts through a shell
    /// (`codex exec` from Claude's Bash tool) is a session of its own, launched by that agent; one an agent starts
    /// directly (an MCP server, the native binary an npm launcher runs) belongs to that agent's session. A
    /// session's CPU time adds up the agent processes that belong to it.
    /// @example AgentSessionFinder.sessions(in: tree, resolver: resolver).map(\.agent) // [.claude, .codex]
    public static func sessions(in tree: ProcessTree, resolver: RepoResolver) -> [AgentSession] {
        let agentProcesses = tree.snapshots.sorted { $0.pid < $1.pid }.compactMap { process in agent(of: process).map { (process, $0) } }
        var owners: [Int32: Owner] = [:]
        for (process, _) in agentProcesses { owners[process.pid] = owner(of: process, in: tree) }
        var cpuBySession: [Int32: UInt64] = [:]
        for (process, _) in agentProcesses {
            let session = sessionPid(of: process.pid, owners: owners)
            cpuBySession[session, default: 0] &+= process.cpuTimeNs
        }
        return agentProcesses.compactMap { process, agent in
            guard case .session(let launchedBy) = owners[process.pid] else { return nil }
            let directories = ([process] + tree.ancestors(of: process.pid)).compactMap(\.workingDirectory)
            return AgentSession(
                agent: agent, process: process, location: directories.lazy.compactMap { resolver.resolve($0) }.first,
                cpuTimeNs: cpuBySession[process.pid] ?? process.cpuTimeNs, launchedBy: launchedBy)
        }
    }

    /// Where an agent process belongs: a session of its own, or the session of the agent process above it.
    private enum Owner {
        case session(launchedBy: Agent?)
        case partOf(Int32)
    }

    /// Returns where an agent process belongs, from the nearest agent process above it and whether a shell
    /// stands between the two.
    /// @example owner(of: codexRunByClaudesBashTool, in: tree) // .session(launchedBy: .claude)
    private static func owner(of process: ProcessSnapshot, in tree: ProcessTree) -> Owner {
        var throughShell = false
        for ancestor in tree.ancestors(of: process.pid) {
            if let launcher = agent(of: ancestor) {
                return throughShell ? .session(launchedBy: launcher) : .partOf(ancestor.pid)
            }
            let role = ProcessRole.of(ancestor)
            if role == .wrapperShell || role == .interactiveShell { throughShell = true }
        }
        return .session(launchedBy: nil)
    }

    /// Returns the pid of the session an agent process belongs to, following `partOf` links up to a session.
    /// @example sessionPid(of: 21, owners: [20: .session(launchedBy: nil), 21: .partOf(20)]) // 20
    private static func sessionPid(of pid: Int32, owners: [Int32: Owner]) -> Int32 {
        var current = pid
        var seen: Set<Int32> = []
        while case .partOf(let parent) = owners[current], seen.insert(current).inserted { current = parent }
        return current
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
