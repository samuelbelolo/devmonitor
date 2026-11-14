import XCTest
@testable import DevMonitorCore

final class AgentReleaseTests: XCTestCase {
    func testLatestVersionIsReadFromTheNpmRegistry() {
        let json = Data(#"{"name":"@openai/codex","version":"0.161.0","dist":{}}"#.utf8)
        XCTAssertEqual(AgentRelease.latest(from: json, for: .codex)?.text, "0.161.0")
    }

    func testLatestVersionIsReadFromPyPI() {
        let json = Data(#"{"info":{"name":"aider-chat","version":"0.90.1"}}"#.utf8)
        XCTAssertEqual(AgentRelease.latest(from: json, for: .aider)?.text, "0.90.1")
    }

    func testAgentWithoutAPublicRegistryHasNoLatestVersionAddress() {
        XCTAssertNil(AgentRelease.latestURL(for: .cursorAgent))
        XCTAssertEqual(AgentRelease.latestURL(for: .claude)?.absoluteString, "https://registry.npmjs.org/@anthropic-ai/claude-code/latest")
    }

    func testAClaudeInstalledByItsInstallerIsComparedWithTheInstallersChannel() {
        // `claude update` reads this channel, which got 2.1.325 half an hour after npm did: asked npm, the app
        // announced a version the command could not install yet.
        let installer = "/Users/me/.local/share/claude/versions/2.1.323"
        XCTAssertEqual(AgentRelease.latestURL(for: .claude, executable: installer)?.absoluteString, "https://downloads.claude.ai/claude-code-releases/latest")
        XCTAssertEqual(AgentRelease.latest(from: Data("2.1.325\n".utf8), for: .claude, executable: installer)?.text, "2.1.325")
        XCTAssertNil(AgentRelease.latest(from: Data("<html>503 Service Unavailable</html>".utf8), for: .claude, executable: installer))
    }

    func testAClaudeInstalledFromNpmIsComparedWithNpm() {
        let npm = "/Users/me/.n/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        XCTAssertEqual(AgentRelease.latestURL(for: .claude, executable: npm)?.absoluteString, "https://registry.npmjs.org/@anthropic-ai/claude-code/latest")
        XCTAssertEqual(AgentRelease.latest(from: Data(#"{"version":"2.1.325"}"#.utf8), for: .claude, executable: npm)?.text, "2.1.325")
        // Another agent's command never changes where it is compared.
        XCTAssertEqual(AgentRelease.latestURL(for: .codex, executable: "/x/claude/versions/1")?.absoluteString, "https://registry.npmjs.org/@openai/codex/latest")
    }

    func testEveryAgentHasAnUpdateCommand() {
        XCTAssertEqual(AgentRelease.updateCommand(for: .claude), "claude update")
        XCTAssertEqual(AgentRelease.updateCommand(for: .codex), "codex update")
        for agent in Agent.allCases { XCTAssertFalse(AgentRelease.updateCommand(for: agent).isEmpty) }
    }

    func testReportIsOutdatedOnlyWhenANewerVersionIsKnown() {
        let installed = VersionNumber(parsing: "2.1.288")
        XCTAssertTrue(AgentVersionReport(agent: .claude, installed: installed, latest: VersionNumber(parsing: "2.1.291")).isOutdated)
        XCTAssertFalse(AgentVersionReport(agent: .claude, installed: installed, latest: installed).isOutdated)
        XCTAssertFalse(AgentVersionReport(agent: .cursorAgent, installed: installed, latest: nil).isOutdated)
    }

    func testSessionsOnAnOlderVersionThanTheInstalledOneAreToRestart() {
        let report = AgentVersionReport(agent: .claude, installed: VersionNumber(parsing: "2.1.288"), latest: nil)
        let old = AgentSession(agent: .claude, process: snap(20, parent: 1, path: "/x/claude-code-2.1.287/claude"), location: nil)
        let current = AgentSession(agent: .claude, process: snap(21, parent: 1, path: "/x/versions/2.1.288"), location: nil)
        let unknown = AgentSession(agent: .claude, process: snap(22, parent: 1, path: "/opt/homebrew/bin/node"), location: nil)
        XCTAssertEqual(report.sessionsToRestart(among: [old, current, unknown]).map(\.process.pid), [20])
    }

    func testEditorExtensionSessionsAreComparedWithTheNewestExtensionInstalled() {
        let report = AgentVersionReport(agent: .claude, installed: VersionNumber(parsing: "2.1.290"), latest: nil)
        let extensions = "/Users/me/.cursor/extensions"
        let session = AgentSession(agent: .claude, process: snap(20, parent: 1, path: extensions + "/anthropic.claude-code-2.1.287-darwin-arm64/resources/native-binary/claude"), location: nil)
        let behindTheCli = ["anthropic.claude-code-2.1.287-darwin-arm64"]
        XCTAssertEqual(report.sessionsToRestart(among: [session], listing: { _ in behindTheCli }).count, 0)
        let updated = ["anthropic.claude-code-2.1.287-darwin-arm64", "anthropic.claude-code-2.1.288-darwin-arm64"]
        XCTAssertEqual(report.sessionsToRestart(among: [session], listing: { $0 == extensions ? updated : [] }).count, 1)
    }
}
