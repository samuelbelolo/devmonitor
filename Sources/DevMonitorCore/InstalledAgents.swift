import Foundation

/// Finds the agents installed on this Mac and asks each one its version.
public enum InstalledAgents {
    /// Returns the installed version of every agent found, in the order of `Agent.allCases`. The probes run side by side.
    /// @example InstalledAgents.versions().map(\.agent) // [.claude, .codex, .cursorAgent]
    public static func versions() -> [(agent: Agent, version: VersionNumber?)] {
        let home = NSHomeDirectory()
        let base = ProcessInfo.processInfo.environment
        let nvmVersions = (try? FileManager.default.contentsOfDirectory(atPath: home + "/.nvm/versions/node")) ?? []
        let folders = searchFolders(home: home, inheritedPath: base["PATH"], nvmVersions: nvmVersions)
        let found = Agent.allCases.compactMap { agent in
            folders.map { $0 + "/" + agent.command }.first(where: FileManager.default.isExecutableFile).map { (agent, $0) }
        }
        var versions = [VersionNumber?](repeating: nil, count: found.count)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: found.count) { index in
            let executable = found[index].1
            let output = CommandRunner.run(executable, ["--version"], timeout: 10, environment: probeEnvironment(for: executable, folders: folders, base: base))
            let version = output.flatMap { VersionNumber(parsing: $0) }
            lock.lock()
            versions[index] = version
            lock.unlock()
        }
        return found.indices.map { (found[$0].0, versions[$0]) }
    }

    /// Returns the folders searched for agent commands, without repeats: the usual install folders, the version
    /// managers' (newest node first), Homebrew, then the PATH the app inherited. An app started from the Dock does
    /// not get the shell's PATH, hence the list.
    /// @example InstalledAgents.searchFolders(home: "/Users/me", inheritedPath: "/usr/bin", nvmVersions: ["v22.11.0"]).first // "/Users/me/.local/bin"
    static func searchFolders(home: String, inheritedPath: String?, nvmVersions: [String]) -> [String] {
        let usual = [".local/bin", ".npm-global/bin", ".bun/bin", ".opencode/bin", ".amp/bin", ".cargo/bin", ".n/bin", ".volta/bin"]
            .map { home + "/" + $0 }
        let nvm = nvmVersions
            .compactMap { name in VersionNumber(parsing: name).map { (name, $0) } }
            .sorted { $0.1 > $1.1 }
            .map { home + "/.nvm/versions/node/\($0.0)/bin" }
        let inherited = (inheritedPath ?? "").split(separator: ":").map(String.init)
        var seen: Set<String> = []
        return (usual + nvm + ["/opt/homebrew/bin", "/usr/local/bin"] + inherited).filter { seen.insert($0).inserted }
    }

    /// Returns the environment a version probe runs with: its PATH starts with the command's own folder, so a
    /// `#!/usr/bin/env node` script finds the node installed beside it.
    /// @example InstalledAgents.probeEnvironment(for: "/Users/me/.n/bin/codex", folders: [], base: [:])["PATH"] // "/Users/me/.n/bin"
    static func probeEnvironment(for executable: String, folders: [String], base: [String: String]) -> [String: String] {
        let own = (executable as NSString).deletingLastPathComponent
        let inherited = (base["PATH"] ?? "").split(separator: ":").map(String.init)
        var seen: Set<String> = []
        var environment = base
        environment["PATH"] = ([own] + folders + inherited).filter { seen.insert($0).inserted }.joined(separator: ":")
        return environment
    }
}
