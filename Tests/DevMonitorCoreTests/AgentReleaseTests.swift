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
