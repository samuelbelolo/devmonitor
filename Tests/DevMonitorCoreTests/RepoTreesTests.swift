import XCTest
@testable import DevMonitorCore

/// Answers requests from a script, one answer per call, and remembers what was asked.
private final class ScriptedGitHub: @unchecked Sendable {
    private let lock = NSLock()
    private var answers: [(data: Data, status: Int, etag: String?)?]
    private(set) var requests: [URLRequest] = []

    init(_ answers: [(data: Data, status: Int, etag: String?)?]) { self.answers = answers }

    /// Records the request and returns the next scripted answer.
    /// @example await github.load(request)
    func load(_ request: URLRequest) async -> (data: Data, status: Int, etag: String?)? {
        lock.withLock {
            requests.append(request)
            return answers.isEmpty ? nil : answers.removeFirst()
        }
    }
}

final class RepoTreesTests: XCTestCase {
    private let source = SkillSource(repo: "acme/kit", ref: nil)
    private let body = Data(#"{"sha":"root1","tree":[{"path":"skills","type":"tree","sha":"s1"}]}"#.utf8)

    func testATreeIsFetchedOncePerSource() async {
        let github = ScriptedGitHub([(body, 200, "\"v1\"")])
        let trees = await RepoTrees { await github.load($0) }.fetch([source, source])
        XCTAssertEqual(trees[source]?.folderSHA("skills"), "s1")
        XCTAssertEqual(github.requests.count, 1)
        XCTAssertNil(github.requests[0].value(forHTTPHeaderField: "If-None-Match"))
    }

    func testAnUnchangedAnswerKeepsTheTreeAndSendsTheETag() async {
        let github = ScriptedGitHub([(body, 200, "\"v1\""), (Data(), 304, nil)])
        let fetcher = RepoTrees { await github.load($0) }
        _ = await fetcher.fetch([source])
        let again = await fetcher.fetch([source])
        XCTAssertEqual(again[source]?.rootSHA, "root1")
        XCTAssertEqual(github.requests[1].value(forHTTPHeaderField: "If-None-Match"), "\"v1\"")
    }

    func testARefusalKeepsTheLastTree() async {
        let refusal = Data(#"{"message":"API rate limit exceeded"}"#.utf8)
        let github = ScriptedGitHub([(body, 200, nil), (refusal, 403, nil), nil])
        let fetcher = RepoTrees { await github.load($0) }
        _ = await fetcher.fetch([source])
        let refused = await fetcher.fetch([source])
        XCTAssertEqual(refused[source]?.rootSHA, "root1")
        let offline = await fetcher.fetch([source])
        XCTAssertEqual(offline[source]?.rootSHA, "root1")
    }

    func testOnlyAnAnswerCountsAsACheck() async throws {
        let refusal = Data(#"{"message":"API rate limit exceeded"}"#.utf8)
        let github = ScriptedGitHub([(refusal, 403, nil), (body, 200, "\"v1\""), nil, (Data(), 304, nil)])
        let fetcher = RepoTrees { await github.load($0) }
        _ = await fetcher.fetch([source])
        var last = await fetcher.lastAnswered
        XCTAssertNil(last)
        _ = await fetcher.fetch([source])
        last = await fetcher.lastAnswered
        let first = try XCTUnwrap(last)
        _ = await fetcher.fetch([source])
        last = await fetcher.lastAnswered
        XCTAssertEqual(last, first)
        _ = await fetcher.fetch([source])
        last = await fetcher.lastAnswered
        XCTAssertGreaterThan(try XCTUnwrap(last), first)
    }

    func testNoAnswerAndNoEarlierTreeGivesNothing() async {
        let trees = await RepoTrees { _ in nil }.fetch([source])
        XCTAssertNil(trees[source])
    }

    func testASourceWithoutAnAddressIsNotAsked() async {
        let github = ScriptedGitHub([])
        let odd = SkillSource(repo: "not a repo", ref: nil)
        let trees = await RepoTrees { await github.load($0) }.fetch([odd])
        XCTAssertTrue(trees.isEmpty)
        XCTAssertTrue(github.requests.isEmpty)
    }
}
