import XCTest
@testable import DevMonitorCore

final class ZedAgentRegistryTests: XCTestCase {
    private let registry = "/Users/me/Library/Application Support/Zed/external_agents/registry/claude-acp"
    private var binary: String { registry + "/v_0.107.2_b5ff793e5d0cd271_8e166642f1769813/claude" }

    func testZedAdapterBinariesAreRecognised() {
        XCTAssertTrue(ZedAgentRegistry.contains(binary))
        XCTAssertFalse(ZedAgentRegistry.contains("/Users/me/.local/share/claude/versions/2.1.288"))
    }

    func testNewestAdapterDownloadedIsFound() {
        let folders = ["v_0.107.2_aa_bb", "v_0.108.0_cc_dd", ".DS_Store"]
        let newest = ZedAgentRegistry.newestVersion(of: binary, listing: { $0 == self.registry ? folders : [] })
        XCTAssertEqual(newest?.text, "0.108.0")
    }

    func testZedSessionsAreNotComparedWithTheClaudeCodeCli() {
        let report = AgentVersionReport(agent: .claude, installed: VersionNumber(parsing: "2.1.326"), latest: nil)
        let session = AgentSession(agent: .claude, process: snap(20, parent: 1, path: binary), location: nil)
        XCTAssertEqual(report.sessionsToRestart(among: [session], listing: { _ in ["v_0.107.2_aa_bb"] }).count, 0)
        XCTAssertEqual(report.sessionsToRestart(among: [session], listing: { _ in ["v_0.108.0_cc_dd"] }).count, 1)
    }
}
