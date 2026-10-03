import XCTest
@testable import DevMonitorCore

final class ServiceBuilderTests: XCTestCase {
    private var home = ""

    override func setUp() {
        home = makeTempDirectory()
        write(home + "/repo/.git/HEAD")
    }

    /// Builds services from snapshots whose paths under /Users/me are remapped to the temp home.
    /// @example services(agentChain()).count // 2
    private func services(_ snapshots: [ProcessSnapshot]) -> [Service] {
        let remapped = snapshots.map { process in
            snap(process.pid, parent: process.ppid, path: process.executablePath, args: process.arguments,
                 cwd: process.workingDirectory?.replacingOccurrences(of: "/Users/me", with: home),
                 ports: process.ports, memory: process.memoryBytes, start: process.startTime)
        }
        return ServiceBuilder(resolver: RepoResolver(home: home)).services(in: ProcessTree(remapped), now: now)
    }

    /// The scan time used by these tests: 60 s after the fixtures' default start time.
    private var now: UInt64 = 160

    func testDevServerStartedByAnAgentIsOneServiceRootedBelowTheShell() {
        let service = services(agentChain()).first { $0.root.pid == 40 }
        XCTAssertEqual(service?.members.map(\.pid), [40, 50])
        XCTAssertEqual(service?.memoryBytes, 200)
        XCTAssertEqual(service?.ports, [5173])
        XCTAssertEqual(service?.agent, .claude)
        XCTAssertEqual(service?.isOrphan, false)
        XCTAssertEqual(service?.isMCP, false)
    }

    func testAgentAndAppProcessesAreNeverPartOfAService() {
        let pids = services(agentChain()).flatMap(\.members).map(\.pid)
        XCTAssertEqual(Set(pids), [40, 50, 60])
    }

    func testProcessAnAgentStartsDirectlyIsAnAgentToolWhateverItsName() {
        let helper = snap(61, parent: 20, path: "/Users/me/.codex/bin/code-mode-host", cwd: "/Users/me/repo")
        let found = services(agentChain() + [helper])
        XCTAssertEqual(found.first { $0.root.pid == 60 }?.isMCP, true)
        XCTAssertEqual(found.first { $0.root.pid == 61 }?.isMCP, true)
    }

    func testOrphanedMcpServerIsRecognisedByTheWordsOfItsCommand() {
        let retitled = snap(62, parent: 1, path: "/opt/homebrew/bin/node", args: ["npm exec chrome-devtools-mcp@1.1.1"], cwd: "/Users/me/repo")
        let serena = snap(63, parent: 1, path: "/Users/me/.cache/uv/bin/python", args: ["python", "/Users/me/.cache/uv/bin/serena", "start-mcp-server"], cwd: "/Users/me/repo")
        XCTAssertEqual(services([retitled, serena]).map(\.isMCP), [true, true])
    }

    func testFolderNamedAfterMcpDoesNotMakeAServiceAnMcpServer() {
        let vite = snap(64, parent: 1, path: "/opt/homebrew/bin/node", args: ["node", "/Users/mcpherson/my-mcp-tools/node_modules/.bin/vite"], cwd: "/Users/me/repo")
        XCTAssertEqual(services([vite]).first?.isMCP, false)
    }

    func testInteractiveShellAloneIsNotAService() {
        XCTAssertTrue(services(terminalChain()).isEmpty)
    }

    func testCommandTypedInATerminalIsAServiceThatLeavesItsShellOut() {
        let node = snap(91, parent: 90, path: "/opt/homebrew/bin/node", args: ["node", "server.js"], cwd: "/Users/me/repo")
        XCTAssertEqual(services(terminalChain() + [node]).map { $0.members.map(\.pid) }, [[91]])
    }

    func testWrapperAroundAnInteractiveShellIsNotAServiceButWhatRunsInsideIs() {
        let wrapper = snap(100, parent: 90, path: "/usr/bin/script", args: ["script", "-q", "/dev/null"], cwd: "/Users/me/repo")
        let inner = snap(101, parent: 100, path: "/bin/zsh", args: ["-zsh"], cwd: "/Users/me/repo")
        let node = snap(102, parent: 101, path: "/opt/homebrew/bin/node", args: ["node", "server.js"], cwd: "/Users/me/repo")
        XCTAssertEqual(services(terminalChain() + [wrapper, inner, node]).map(\.root.pid), [102])
    }

    func testWrapperAroundAnAgentSessionIsNotAService() {
        let wrapper = snap(110, parent: 90, path: "/opt/homebrew/bin/op", args: ["op", "run", "--", "claude"], cwd: "/Users/me/repo")
        let session = snap(111, parent: 110, path: "/Users/me/.local/bin/claude", args: ["claude"], cwd: "/Users/me/repo")
        XCTAssertTrue(services(terminalChain() + [wrapper, session]).isEmpty)
    }

    func testEditorAndRemoteSessionOpenedInARepoAreNotServices() {
        let editor = snap(120, parent: 90, path: "/opt/homebrew/bin/nvim", args: ["nvim", "README.md"], cwd: "/Users/me/repo")
        let tunnel = snap(121, parent: 90, path: "/usr/bin/ssh", args: ["ssh", "-N", "-L", "5432:db:5432", "bastion"], cwd: "/Users/me/repo")
        XCTAssertTrue(services(terminalChain() + [editor, tunnel]).isEmpty)
    }

    func testServerRunByFrameworkPythonIsListed() {
        let python = snap(130, parent: 90, path: "/opt/homebrew/Cellar/python@3.14/3.14.7/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python", args: ["python3", "manage.py", "runserver"], cwd: "/Users/me/repo")
        XCTAssertEqual(services(terminalChain() + [python]).map(\.root.pid), [130])
    }

    func testProcessAdoptedByLaunchdIsAnOrphan() {
        let node = snap(80, parent: 1, path: "/opt/homebrew/bin/node", args: ["node", "server.js"], cwd: "/Users/me/repo")
        XCTAssertEqual(services([node]).first?.isOrphan, true)
    }

    func testProcessWithoutAProjectDirectoryUsesItsAncestors() {
        let node = snap(91, parent: 90, path: "/opt/homebrew/bin/node", args: ["node", "x.js"], cwd: "/")
        XCTAssertEqual(services(terminalChain() + [node]).first?.location.name, "repo")
    }

    func testProcessOutsideAnyProjectIsIgnored() {
        let daemon = snap(95, parent: 1, path: "/usr/local/bin/syncthing", cwd: "/")
        XCTAssertTrue(services([daemon]).isEmpty)
    }

    func testCommandStartedLessThanTwentySecondsAgoIsNotListedYet() {
        let node = snap(80, parent: 1, path: "/opt/homebrew/bin/node", args: ["node", "server.js"], cwd: "/Users/me/repo", start: 150)
        XCTAssertTrue(services([node]).isEmpty)
    }

    func testHelperSpawnedDirectlyByAnAppIsIgnored() {
        let server = snap(85, parent: 10, path: "/Users/me/.cursor/docker-language-server", args: ["docker-language-server", "start"], cwd: "/Users/me/repo")
        XCTAssertTrue(services([agentChain()[0], server]).isEmpty)
    }
}
