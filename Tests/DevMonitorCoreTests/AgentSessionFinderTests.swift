import XCTest
@testable import DevMonitorCore

final class AgentSessionFinderTests: XCTestCase {
    private var home = ""

    override func setUp() {
        home = makeTempDirectory()
        write(home + "/shop/.git/HEAD")
        write(home + "/api/.git/HEAD")
    }

    /// Finds the sessions among processes whose working directories are given relative to the temp home.
    /// @example sessions([snap(20, parent: 1, path: "/bin/claude", cwd: "shop")]).count // 1
    private func sessions(_ processes: [ProcessSnapshot]) -> [AgentSession] {
        let remapped = processes.map { process in
            snap(process.pid, parent: process.ppid, path: process.executablePath, args: process.arguments,
                 cwd: process.workingDirectory.map { home + "/" + $0 }, cpu: process.cpuTimeNs)
        }
        return AgentSessionFinder.sessions(in: ProcessTree(remapped), resolver: RepoResolver(home: home))
    }

    func testEachAgentProcessIsASessionInTheProjectItRunsIn() {
        let found = sessions([
            snap(20, parent: 1, path: "/Users/me/.local/bin/claude", args: ["claude"], cwd: "shop"),
            snap(30, parent: 1, path: "/Users/me/.local/bin/codex", args: ["codex"], cwd: "api"),
        ])
        XCTAssertEqual(found.map(\.agent), [.claude, .codex])
        XCTAssertEqual(found.map(\.location?.name), ["shop", "api"])
    }

    func testAgentStartedByAnotherAgentBelongsToTheFirstSession() {
        let found = sessions([
            snap(20, parent: 1, path: "/Users/me/.local/bin/claude", args: ["claude"], cwd: "shop"),
            snap(21, parent: 20, path: "/Users/me/.local/bin/codex", args: ["codex", "exec", "review"], cwd: "shop"),
        ])
        XCTAssertEqual(found.map(\.process.pid), [20])
    }

    func testWrapperAndAgentCountAsOneSession() {
        let found = sessions([
            snap(20, parent: 1, path: "/opt/homebrew/bin/node", args: ["node", "/opt/homebrew/lib/node_modules/@openai/codex/bin/codex.js"], cwd: "api"),
            snap(21, parent: 20, path: "/opt/homebrew/lib/node_modules/@openai/codex/vendor/codex", args: ["codex"], cwd: "api"),
        ])
        XCTAssertEqual(found.map(\.process.pid), [20])
    }

    func testSessionOutsideAnyProjectHasNoLocation() {
        let found = sessions([snap(20, parent: 1, path: "/Users/me/.local/bin/claude", args: ["claude"], cwd: "notes")])
        XCTAssertEqual(found.count, 1)
        XCTAssertNil(found[0].location)
    }

    func testToolTheAgentBinaryRunsUnderAnotherNameIsNotASession() {
        let binary = "/Users/me/.cursor/extensions/anthropic.claude-code-2.1.288-darwin-arm64/resources/native-binary/claude"
        let found = sessions([
            snap(20, parent: 1, path: binary, args: [binary, "--output-format", "stream-json"], cwd: "shop"),
            snap(40, parent: 1, path: binary, args: ["ugrep", "-G", "--hidden"], cwd: "shop"),
        ])
        XCTAssertEqual(found.map(\.process.pid), [20])
    }

    func testWrapperSessionCountsTheCpuOfItsAgentChild() {
        let found = sessions([
            snap(20, parent: 1, path: "/opt/homebrew/bin/node", args: ["node", "/opt/homebrew/lib/node_modules/@openai/codex/bin/codex.js"], cwd: "api", cpu: 1_000),
            snap(21, parent: 20, path: "/opt/homebrew/lib/node_modules/@openai/codex/vendor/codex", args: ["codex"], cwd: "api", cpu: 5_000),
            snap(22, parent: 21, path: "/opt/homebrew/bin/node", args: ["node", "/Users/me/mcp/index.js"], cwd: "api", cpu: 9_000),
        ])
        XCTAssertEqual(found.map(\.cpuTimeNs), [6_000])
    }

    func testOrphanedToolOfNativeClaudeIsNotASession() {
        let binary = "/Users/me/.local/share/claude/versions/2.1.288"
        let found = sessions([
            snap(20, parent: 1, path: binary, args: ["claude"], cwd: "shop"),
            snap(40, parent: 1, path: binary, args: ["ugrep", "-G", "--hidden"], cwd: "shop"),
        ])
        XCTAssertEqual(found.map(\.process.pid), [20])
    }

    func testAgentRunByFrameworkPythonIsASession() {
        let python = "/opt/homebrew/Cellar/python@3.12/3.12.7/Frameworks/Python.framework/Versions/3.12/Resources/Python.app/Contents/MacOS/Python"
        let found = sessions([snap(20, parent: 1, path: python, args: ["/opt/homebrew/bin/python3.12", "/Users/me/.local/bin/aider"], cwd: "shop")])
        XCTAssertEqual(found.map(\.agent), [.aider])
        XCTAssertNil(found.first?.version)
    }

    func testSessionRunByAVersionedNodeHasNoVersion() {
        let found = sessions([
            snap(20, parent: 1, path: "/opt/homebrew/Cellar/node/24.1.0/bin/node", args: ["node", "/opt/homebrew/lib/node_modules/@google/gemini-cli/dist/index.js"], cwd: "api"),
            snap(30, parent: 1, path: "/Users/me/.nvm/versions/node/v22.11.0/bin/node", args: ["node", "/Users/me/.nvm/versions/node/v22.11.0/lib/node_modules/@openai/codex/bin/codex.js"], cwd: "api"),
        ])
        XCTAssertEqual(found.map(\.agent), [.gemini, .codex])
        XCTAssertEqual(found.map(\.version?.text), [nil, nil])
    }

    func testSessionKnowsTheVersionItRuns() {
        let found = sessions([
            snap(20, parent: 1, path: "/Users/me/.cursor/extensions/anthropic.claude-code-2.1.287-darwin-arm64/resources/native-binary/claude", args: ["claude"], cwd: "shop"),
            snap(30, parent: 1, path: "/Users/me/.local/share/claude/versions/2.1.288", args: ["claude"], cwd: "shop"),
            snap(40, parent: 1, path: "/opt/homebrew/bin/node", args: ["node", "/opt/homebrew/lib/node_modules/@openai/codex/bin/codex.js"], cwd: "api"),
        ])
        XCTAssertEqual(found.map(\.version?.text), ["2.1.287", "2.1.288", nil])
    }
}
