import Foundation
@testable import DevMonitorCore

/// Builds a process snapshot for tests, with defaults for every field but the pids.
/// @example snap(10, parent: 1, path: "/usr/bin/node") // a node process whose parent is launchd
func snap(
    _ pid: Int32, parent: Int32, path: String, args: [String] = [], cwd: String? = nil,
    ports: [UInt16] = [], memory: UInt64 = 0, cpu: UInt64 = 0, start: UInt64 = 100
) -> ProcessSnapshot {
    ProcessSnapshot(
        pid: pid, ppid: parent, startTime: start, executablePath: path,
        arguments: args.isEmpty ? [path] : args, workingDirectory: cwd, ports: ports,
        memoryBytes: memory, cpuTimeNs: cpu)
}

/// A typical chain: an editor helper, a claude session, the shell it spawned, a dev server and an MCP server.
/// @example ProcessTree(agentChain()).snapshot(pid: 50)?.name // "node"
func agentChain() -> [ProcessSnapshot] {
    [
        snap(10, parent: 1, path: "/Applications/Cursor.app/Contents/Frameworks/Cursor Helper (Plugin).app/Contents/MacOS/Cursor Helper (Plugin)"),
        snap(20, parent: 10, path: "/Users/me/.local/bin/claude", args: ["claude"], cwd: "/Users/me/repo"),
        snap(30, parent: 20, path: "/bin/zsh", args: ["zsh", "-c", "pnpm dev"], cwd: "/Users/me/repo"),
        snap(40, parent: 30, path: "/opt/homebrew/bin/pnpm", args: ["pnpm", "dev"], cwd: "/Users/me/repo", memory: 50),
        snap(50, parent: 40, path: "/opt/homebrew/bin/node", args: ["node", "/Users/me/repo/node_modules/.bin/vite"], cwd: "/Users/me/repo", ports: [5173], memory: 150),
        snap(60, parent: 20, path: "/Users/me/.cache/uv/bin/python", args: ["python", "/Users/me/.cache/uv/bin/serena", "start-mcp-server"], cwd: "/Users/me/repo", ports: [24282], memory: 40),
    ]
}

/// A terminal app and the login shell of one of its tabs, opened in a repository.
/// @example ProcessRole.of(terminalChain()[1]) // .interactiveShell
func terminalChain() -> [ProcessSnapshot] {
    [
        snap(10, parent: 1, path: "/Applications/Ghostty.app/Contents/MacOS/ghostty"),
        snap(90, parent: 10, path: "/bin/zsh", args: ["-zsh"], cwd: "/Users/me/repo"),
    ]
}
