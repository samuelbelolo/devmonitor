import Foundation

/// Asks the public registries for the latest published version of each agent.
public enum LatestVersions {
    /// Returns the latest version of each installed agent that answered, asked where that install is updated from;
    /// only the package address is sent, nothing about the Mac.
    /// @example await LatestVersions.fetch(InstalledAgents.executables()) // [.claude: 2.1.288, .codex: 0.160.0]
    public static func fetch(_ installed: [(agent: Agent, path: String)]) async -> [Agent: VersionNumber] {
        await withTaskGroup(of: (Agent, VersionNumber?).self) { group in
            for (agent, path) in installed {
                // An update points the command at a new file: where that file lives tells who installed it.
                let executable = (path as NSString).resolvingSymlinksInPath
                group.addTask { (agent, await latest(of: agent, executable: executable)) }
            }
            var result: [Agent: VersionNumber] = [:]
            for await (agent, version) in group {
                if let version { result[agent] = version }
            }
            return result
        }
    }

    /// Returns the latest published version of one agent, or nil when it has no registry or the registry did not
    /// answer; `executable` is its installed command with its links followed.
    /// @example await latest(of: .codex, executable: "/Users/me/.n/bin/codex")?.text // "0.160.0"
    private static func latest(of agent: Agent, executable: String) async -> VersionNumber? {
        guard let url = AgentRelease.latestURL(for: agent, executable: executable) else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/json, text/plain", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return AgentRelease.latest(from: data, for: agent, executable: executable)
    }
}
