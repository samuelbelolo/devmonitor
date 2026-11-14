import DevMonitorCore
import Foundation

/// The made-up Mac the documentation's images show: three projects, nine agent sessions, and extensions to update.
/// Nothing here is read from the Mac that renders the images.
enum SampleData {
    private static let home = "/Users/dev"
    private static let megabyte: Double = 1_048_576
    private static let installedMemory: UInt64 = 48 * 1_073_741_824

    /// Returns the scan of the sample Mac, its swap in the given state.
    /// @example SampleData.scan(swap: .critical).swap?.state // .critical
    static func scan(swap state: SwapState) -> ScanResult {
        let services = webAppServices + [myTool, vite] + mcpServers
        let sessions = agentSessions
        return ScanResult(
            groups: ProjectGrouper.groups(services: services, containers: containers),
            idleSeconds: [vite.id: 4 * 3600],
            agentSessions: sessions,
            // Three sessions of web-app and one of shop-front are at work.
            workingSessions: Set([0, 1, 2, 6].map { sessions[$0].id }),
            processIdentities: [],
            swap: swap(state))
    }

    /// Returns the swap of the sample Mac, which has 48 GB of memory, in the given state.
    /// @example SampleData.swap(.critical).usedBytes // 30.5 GB
    static func swap(_ state: SwapState) -> SwapUsage {
        SwapUsage(usedBytes: swapBytes(for: state), installedBytes: installedMemory)
    }

    /// The versions of the sample Mac: a Claude with an update published, a Codex up to date.
    static let versions = [
        AgentVersionReport(agent: .claude, installed: VersionNumber(parsing: "2.1.288"), latest: VersionNumber(parsing: "2.1.291")),
        AgentVersionReport(agent: .codex, installed: VersionNumber(parsing: "0.160.0"), latest: VersionNumber(parsing: "0.160.0")),
    ]

    /// The skills and plugins of the sample Mac: 24 skills from 5 repositories, 9 plugins from 2 marketplaces.
    static let extensions = ExtensionReport(
        skills: [
            skills("acme/agent-skills", outdated: ["audit", "seo-kit", "deploy-check"], current: ["release-notes", "api-review", "db-schema", "onboarding", "triage"]),
            skills("example-labs/skills", outdated: ["lint-rules", "changelog"], current: ["test-plan", "refactor", "i18n", "perf"]),
            skills("dev-tools/skills", outdated: ["db-migrate"], current: ["docker", "ci", "logs", "secrets"]),
            skills("octo/skills", outdated: [], current: ["commit", "review", "plan"]),
            skills("solo/skill-pack", outdated: [], current: ["notes", "standup"]),
        ],
        plugins: [
            plugins("acme-marketplace", outdated: ["lint"], current: ["format", "deploy", "docs", "tests", "metrics"]),
            plugins("community", outdated: [], current: ["themes", "git-tools", "snippets"]),
        ],
        staleCatalogs: 0)

    /// Returns the swap in use that puts a Mac with 48 GB of memory in this state.
    /// @example SampleData.swapBytes(for: .fine) // 1.2 GB
    private static func swapBytes(for state: SwapState) -> UInt64 {
        switch state {
        case .fine: UInt64(1.2 * 1024 * megabyte)
        case .high: UInt64(14.3 * 1024 * megabyte)
        case .critical: UInt64(30.5 * 1024 * megabyte)
        }
    }

    /// Returns a process of the sample Mac; a parent of 1 makes it an orphan.
    /// @example process(101, parent: 1, megabytes: 1946).memoryBytes // 1.9 GB
    private static func process(_ pid: Int32, parent: Int32 = 500, path: String = "/usr/local/bin/node", ports: [UInt16] = [], megabytes: Double) -> ProcessSnapshot {
        ProcessSnapshot(
            pid: pid, ppid: parent, startTime: 1_700_000_000 + UInt64(pid), executablePath: path, arguments: [],
            workingDirectory: nil, ports: ports, memoryBytes: UInt64(megabytes * megabyte), cpuTimeNs: 0)
    }

    /// Returns where a process of a sample project runs.
    /// @example location("web-app", worktree: "feat-billing", package: "apps/api").name // "web-app"
    private static func location(_ project: String, worktree: String? = nil, package: String? = nil) -> ProjectLocation {
        ProjectLocation(root: "\(home)/code/\(project)", name: project, worktree: worktree, package: package)
    }

    /// Three type checkers an agent left behind in a worktree of web-app.
    private static let webAppServices: [Service] = [1946, 1843, 1843].enumerated().map { index, megabytes in
        let root = process(Int32(101 + index), parent: 1, megabytes: megabytes)
        return Service(root: root, members: [root], label: "type-checker", location: location("web-app", worktree: "feat-billing", package: "apps/api"), agent: nil, isMCP: false)
    }

    /// The Compose containers of web-app, 3.3 GB together.
    private static let containers: [DockerContainer] = ["cache", "db", "storage", "mail", "queue", "docs"].map { name in
        DockerContainer(id: "sample-\(name)", name: name, projectRoot: "\(home)/code/web-app", projectName: "web-app", memoryBytes: UInt64(563.2 * megabyte))
    }

    /// An orphan server of my-tool, with one child.
    private static let myTool: Service = {
        let root = process(201, parent: 1, ports: [4000], megabytes: 100)
        return Service(root: root, members: [root, process(202, parent: 201, megabytes: 32)], label: "my-tool", location: location("my-tool"), agent: nil, isMCP: false)
    }()

    /// A dev server Claude started in shop-front and that has done nothing for four hours.
    private static let vite: Service = {
        let root = process(301, ports: [5173], megabytes: 35)
        return Service(root: root, members: [root], label: "vite", location: location("shop-front"), agent: .claude, isMCP: false)
    }()

    /// Eight MCP servers of eleven processes each: 88 processes holding 10 GB.
    private static let mcpServers: [Service] = ["github", "browser", "postgres", "search", "docs", "sentry", "figma", "files"].enumerated().map { index, name in
        let members = (0..<11).map { process(Int32(1000 + index * 20 + $0), megabytes: 10_240.0 / 88) }
        return Service(root: members[0], members: members, label: name, location: location("web-app"), agent: .claude, isMCP: true)
    }

    /// Nine Claude sessions: six in web-app, two in shop-front, one in my-tool; the last one runs an older version.
    private static let agentSessions: [AgentSession] = ["web-app", "web-app", "web-app", "web-app", "web-app", "web-app", "shop-front", "shop-front", "my-tool"]
        .enumerated().map { index, project in
            let version = index == 8 ? "2.1.287" : "2.1.288"
            let path = "\(home)/.local/share/claude/versions/\(version)"
            return AgentSession(agent: .claude, process: process(Int32(401 + index), path: path, megabytes: 300), location: location(project))
        }

    /// Returns a repository of skills, the outdated ones first.
    /// @example skills("acme/agent-skills", outdated: ["audit"], current: ["triage"]).updates // 1
    private static func skills(_ repository: String, outdated: [String], current: [String]) -> ExtensionSource {
        let items = outdated.map { item($0, of: repository, state: .updateAvailable) } + current.map { item($0, of: repository, state: .upToDate) }
        return ExtensionSource(kind: .skills, name: repository, items: items, command: ExtensionCommand.updateSkills(outdated))
    }

    /// Returns a marketplace of plugins, the outdated ones first, each with the command that updates it.
    /// @example plugins("community", outdated: [], current: ["themes"]).updates // 0
    private static func plugins(_ marketplace: String, outdated: [String], current: [String]) -> ExtensionSource {
        let stale = outdated.map { item($0, of: marketplace, state: .updateAvailable, command: "claude plugin update \($0)@\(marketplace) --scope user") }
        return ExtensionSource(kind: .plugins, name: marketplace, items: stale + current.map { item($0, of: marketplace, state: .upToDate) }, command: nil)
    }

    /// Returns one skill or plugin of a source.
    /// @example item("audit", of: "acme/agent-skills", state: .upToDate).name // "audit"
    private static func item(_ name: String, of source: String, state: ExtensionState, command: String? = nil) -> ExtensionItem {
        ExtensionItem(id: "\(source)/\(name)", name: name, detail: nil, state: state, command: command)
    }
}
