import XCTest
@testable import DevMonitorCore

/// Asks GitHub's real git server, outside the API's hourly limit. Skipped unless `DEVMON_LIVE_NETWORK=1`, so the
/// suite stays offline: `DEVMON_LIVE_NETWORK=1 swift test --filter LiveRepoHeadsTests`.
final class LiveRepoHeadsTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DEVMON_LIVE_NETWORK"] == "1", "network test")
    }

    func testTheRealServerGivesTheHeadCommit() async throws {
        let commit = await RepoHeads.overTheNetwork(SkillSource(repo: "vercel-labs/skills", ref: nil))
        XCTAssertTrue(SkillSource.isCommitHash(try XCTUnwrap(commit)))
    }

    func testTheRealServerGivesABranchCommit() async throws {
        let commit = await RepoHeads.overTheNetwork(SkillSource(repo: "vercel-labs/skills", ref: "main"))
        XCTAssertTrue(SkillSource.isCommitHash(try XCTUnwrap(commit)))
    }
}
