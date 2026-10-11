import XCTest
@testable import DevMonitorCore

/// Asks GitHub's real git server, outside the API's hourly limit. Skipped unless `DEVMON_LIVE_NETWORK=1`, so the
/// suite stays offline: `DEVMON_LIVE_NETWORK=1 swift test --filter LiveRepoHeadsTests`.
final class LiveRepoHeadsTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DEVMON_LIVE_NETWORK"] == "1", "network test")
    }

    func testTheRealServerGivesTheHeadCommit() async throws {
        let commit = try await head(of: SkillSource(repo: "vercel-labs/skills", ref: nil))
        XCTAssertTrue(SkillSource.isCommitHash(try XCTUnwrap(commit)))
    }

    func testTheRealServerGivesABranchCommit() async throws {
        let commit = try await head(of: SkillSource(repo: "vercel-labs/skills", ref: "main"))
        XCTAssertTrue(SkillSource.isCommitHash(try XCTUnwrap(commit)))
    }

    /// Sends the source's `ls-refs` request over the network and reads the commit from the answer.
    /// @example try await head(of: SkillSource(repo: "vercel-labs/skills", ref: nil)) // "13e4…"
    private func head(of source: SkillSource) async throws -> String? {
        let request = try XCTUnwrap(RepoHeads.request(for: source))
        let loaded = await RepoTrees.overTheNetwork(request)
        let answer = try XCTUnwrap(loaded)
        XCTAssertEqual(answer.status, 200)
        return RepoHeads.commit(in: answer.data, for: source)
    }
}
