import XCTest
@testable import DevMonitorCore

final class RepoHeadsTests: XCTestCase {
    private let branch = String(repeating: "b1", count: 20)
    private let tag = String(repeating: "7a", count: 20)
    private let target = String(repeating: "c0", count: 20)

    /// Returns an `ls-refs` answer listing these lines.
    /// @example answer(["\(sha) HEAD"])
    private func answer(_ lines: [String]) -> Data {
        Data((lines.map { PktLine.encode($0 + "\n") }.joined() + PktLine.flush).utf8)
    }

    func testTheRequestAsksOnlyForTheRefOfTheSource() throws {
        let head = try XCTUnwrap(RepoHeads.request(for: SkillSource(repo: "acme/kit", ref: nil)))
        XCTAssertEqual(head.url?.absoluteString, "https://github.com/acme/kit.git/git-upload-pack")
        XCTAssertEqual(head.httpMethod, "POST")
        XCTAssertEqual(head.value(forHTTPHeaderField: "Git-Protocol"), "version=2")
        XCTAssertEqual(head.httpBody.map { String(decoding: $0, as: UTF8.self) }, "0014command=ls-refs\n00010009peel\n0014ref-prefix HEAD\n0000")
        let pinned = try XCTUnwrap(RepoHeads.request(for: SkillSource(repo: "acme/kit", ref: "v2")))
        let body = pinned.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
        XCTAssertTrue(body.contains("ref-prefix refs/heads/v2\n"))
        XCTAssertTrue(body.contains("ref-prefix refs/tags/v2\n"))
        XCTAssertNil(RepoHeads.request(for: SkillSource(repo: "not a repo", ref: nil)))
    }

    func testTheHeadCommitIsRead() {
        let data = answer(["\(branch) HEAD symref-target:refs/heads/main"])
        XCTAssertEqual(RepoHeads.commit(in: data, for: SkillSource(repo: "acme/kit", ref: nil)), branch)
    }

    func testABranchComesBeforeATagAndATagGivesItsTarget() {
        let source = SkillSource(repo: "acme/kit", ref: "v2")
        let both = answer(["\(tag) refs/tags/v2 peeled:\(target)", "\(branch) refs/heads/v2", "\(tag) refs/heads/v2-old"])
        XCTAssertEqual(RepoHeads.commit(in: both, for: source), branch)
        XCTAssertEqual(RepoHeads.commit(in: answer(["\(tag) refs/tags/v2 peeled:\(target)"]), for: source), target)
    }

    func testAMissingRefOrAnOddAnswerGivesNothing() {
        let source = SkillSource(repo: "acme/kit", ref: "v2")
        XCTAssertNil(RepoHeads.commit(in: answer(["\(branch) refs/heads/v2-old"]), for: source))
        XCTAssertNil(RepoHeads.commit(in: answer(["main HEAD"]), for: SkillSource(repo: "acme/kit", ref: nil)))
        XCTAssertNil(RepoHeads.commit(in: Data("<html>".utf8), for: source))
    }
}
