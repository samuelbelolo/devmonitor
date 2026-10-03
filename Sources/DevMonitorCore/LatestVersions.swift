import Foundation

/// Asks the public registries for the latest published version of each agent.
public enum LatestVersions {
    /// Returns the latest version of each agent that answered; only the package address is sent, nothing about the Mac.
    /// @example await LatestVersions.fetch([.claude, .codex]) // [.claude: 2.1.288, .codex: 0.160.0]
    public static func fetch(_ agents: [Agent]) async -> [Agent: VersionNumber] {
        await withTaskGroup(of: (Agent, VersionNumber?).self) { group in
            for agent in agents {
                group.addTask { (agent, await latest(of: agent)) }
            }
            var result: [Agent: VersionNumber] = [:]
            for await (agent, version) in group {
                if let version { result[agent] = version }
            }
            return result
        }
    }

    /// Returns the latest published version of one agent, or nil when it has no registry or the registry did not answer.
    /// @example await latest(of: .codex)?.text // "0.160.0"
    private static func latest(of agent: Agent) async -> VersionNumber? {
        guard let url = AgentRelease.latestURL(for: agent) else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return AgentRelease.latest(from: data, for: agent)
    }
}
