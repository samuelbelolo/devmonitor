import XCTest
@testable import DevMonitorCore

/// Answers the git server with scripted commits and the API with scripted answers, and remembers what the API was asked.
private final class ScriptedGitHub: @unchecked Sendable {
    private let lock = NSLock()
    private var commits: [String?]
    private var answers: [(data: Data, status: Int)?]
    private(set) var apiRequests: [URLRequest] = []
    private(set) var gitRequests = 0

    /// The git server gives the commits in order, then the last one again; the API gives the answers in order, then nothing.
    init(commits: [String?], answers: [(data: Data, status: Int)?]) {
        self.commits = commits
        self.answers = answers
    }

    /// Returns the next scripted answer for the server the request is for.
    /// @example await github.load(request)
    func load(_ request: URLRequest) async -> (data: Data, status: Int)? {
        lock.withLock {
            guard request.url?.lastPathComponent != "git-upload-pack" else {
                gitRequests += 1
                let commit = commits.count > 1 ? commits.removeFirst() : commits.first ?? nil
                return commit.map { (Data((PktLine.encode("\($0) HEAD\n") + PktLine.flush).utf8), 200) }
            }
            apiRequests.append(request)
            return answers.isEmpty ? nil : answers.removeFirst()
        }
    }
}

/// A clock the test moves by hand.
private final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date(timeIntervalSince1970: 0)

    /// Returns the current date.
    /// @example clock.now() // 1970-01-01
    func now() -> Date { lock.withLock { date } }

    /// Moves the clock forward.
    /// @example clock.advance(by: 3600)
    func advance(by seconds: TimeInterval) { lock.withLock { date += seconds } }
}

final class RepoTreesTests: XCTestCase {
    private let source = SkillSource(repo: "acme/kit", ref: nil)
    private let body = Data(#"{"sha":"root1","tree":[{"path":"skills","type":"tree","sha":"s1"}]}"#.utf8)
    private let c1 = String(repeating: "c1", count: 20)
    private let c2 = String(repeating: "c2", count: 20)
    private let c3 = String(repeating: "c3", count: 20)

    /// Returns a fetcher on a scripted GitHub and a hand-moved clock.
    /// @example trees(github)
    private func trees(_ github: ScriptedGitHub, clock: Clock = Clock()) -> RepoTrees {
        RepoTrees(load: { await github.load($0) }, now: { clock.now() })
    }

    func testATreeIsFetchedOncePerSourceAtItsCommit() async {
        let github = ScriptedGitHub(commits: [c1], answers: [(body, 200)])
        let fetched = await trees(github).fetch([source, source])
        XCTAssertEqual(fetched[source]?.folderSHA("skills"), "s1")
        XCTAssertEqual(github.apiRequests.map { $0.url?.absoluteString }, ["https://api.github.com/repos/acme/kit/git/trees/\(c1)?recursive=1"])
    }

    func testTheSameCommitIsNotAskedToTheAPIAgain() async {
        let github = ScriptedGitHub(commits: [c1], answers: [(body, 200)])
        let fetcher = trees(github)
        _ = await fetcher.fetch([source])
        let again = await fetcher.fetch([source])
        XCTAssertEqual(again[source]?.rootSHA, "root1")
        XCTAssertEqual(github.apiRequests.count, 1)
        XCTAssertEqual(github.gitRequests, 2)
    }

    func testANewCommitAsksForTheTreeAtThatCommit() async {
        let newer = Data(#"{"sha":"root2","tree":[]}"#.utf8)
        let github = ScriptedGitHub(commits: [c1, c2], answers: [(body, 200), (newer, 200)])
        let fetcher = trees(github)
        _ = await fetcher.fetch([source])
        let moved = await fetcher.fetch([source])
        XCTAssertEqual(moved[source]?.rootSHA, "root2")
        XCTAssertEqual(github.apiRequests.last?.url?.absoluteString, "https://api.github.com/repos/acme/kit/git/trees/\(c2)?recursive=1")
    }

    func testARefusalKeepsTheLastTree() async {
        let refusal = Data(#"{"message":"API rate limit exceeded"}"#.utf8)
        let github = ScriptedGitHub(commits: [c1, c2, c3], answers: [(body, 200), (refusal, 403), nil])
        let fetcher = trees(github)
        _ = await fetcher.fetch([source])
        let refused = await fetcher.fetch([source])
        XCTAssertEqual(refused[source]?.rootSHA, "root1")
        let offline = await fetcher.fetch([source])
        XCTAssertEqual(offline[source]?.rootSHA, "root1")
    }

    func testOnlyAnAnswerCountsAsACheck() async throws {
        let refusal = Data(#"{"message":"API rate limit exceeded"}"#.utf8)
        let clock = Clock()
        let github = ScriptedGitHub(commits: [c1, c1, c2, c1], answers: [(refusal, 403), (body, 200), nil])
        let fetcher = trees(github, clock: clock)
        _ = await fetcher.fetch([source])
        var last = await fetcher.lastAnswered
        XCTAssertNil(last)
        _ = await fetcher.fetch([source])
        last = await fetcher.lastAnswered
        let first = try XCTUnwrap(last)
        clock.advance(by: 60)
        _ = await fetcher.fetch([source])
        last = await fetcher.lastAnswered
        XCTAssertEqual(last, first)
        clock.advance(by: 60)
        _ = await fetcher.fetch([source])
        last = await fetcher.lastAnswered
        XCTAssertGreaterThan(try XCTUnwrap(last), first)
    }

    func testWithoutACommitTheRefIsAskedAtMostEverySixHours() async {
        let clock = Clock()
        let github = ScriptedGitHub(commits: [nil], answers: [(body, 200), (body, 200)])
        let fetcher = trees(github, clock: clock)
        _ = await fetcher.fetch([source])
        clock.advance(by: 3600)
        let kept = await fetcher.fetch([source])
        XCTAssertEqual(kept[source]?.rootSHA, "root1")
        XCTAssertEqual(github.apiRequests.count, 1)
        XCTAssertEqual(github.apiRequests[0].url?.absoluteString, "https://api.github.com/repos/acme/kit/git/trees/HEAD?recursive=1")
        clock.advance(by: 6 * 3600)
        _ = await fetcher.fetch([source])
        XCTAssertEqual(github.apiRequests.count, 2)
    }

    func testARefThatIsACommitIsItsOwnCommit() async {
        let pinned = SkillSource(repo: "acme/kit", ref: c1)
        let github = ScriptedGitHub(commits: [nil], answers: [(body, 200)])
        let fetcher = trees(github)
        _ = await fetcher.fetch([pinned])
        let again = await fetcher.fetch([pinned])
        XCTAssertEqual(again[pinned]?.rootSHA, "root1")
        XCTAssertEqual(github.gitRequests, 0)
        XCTAssertEqual(github.apiRequests.map { $0.url?.absoluteString }, ["https://api.github.com/repos/acme/kit/git/trees/\(c1)?recursive=1"])
    }

    func testNoAnswerAndNoEarlierTreeGivesNothing() async {
        let fetched = await RepoTrees(load: { _ in nil }).fetch([source])
        XCTAssertNil(fetched[source])
    }

    func testASourceWithoutAnAddressIsNotAsked() async {
        let github = ScriptedGitHub(commits: [c1], answers: [])
        let odd = SkillSource(repo: "not a repo", ref: nil)
        let fetched = await trees(github).fetch([odd])
        XCTAssertTrue(fetched.isEmpty)
        XCTAssertTrue(github.apiRequests.isEmpty)
        XCTAssertEqual(github.gitRequests, 0)
    }
}
