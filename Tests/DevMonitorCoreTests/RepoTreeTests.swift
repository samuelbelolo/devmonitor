import XCTest
@testable import DevMonitorCore

final class RepoTreeTests: XCTestCase {
    func testFoldersAndTheRootAreRead() {
        let json = Data(#"""
        {"sha":"root1","truncated":false,"tree":[
          {"path":"skills","type":"tree","sha":"s1"},
          {"path":"skills/audit","type":"tree","sha":"a1"},
          {"path":"skills/audit/SKILL.md","type":"blob","sha":"b1"}]}
        """#.utf8)
        let tree = RepoTree(parsing: json)
        XCTAssertEqual(tree?.folderSHA("skills/audit"), "a1")
        XCTAssertEqual(tree?.folderSHA(""), "root1")
        XCTAssertNil(tree?.folderSHA("skills/audit/SKILL.md"))
        XCTAssertEqual(tree?.isTruncated, false)
    }

    func testATruncatedTreeSaysSo() {
        XCTAssertEqual(RepoTree(parsing: Data(#"{"sha":"r","truncated":true,"tree":[]}"#.utf8))?.isTruncated, true)
    }

    func testARefusalIsNotATree() {
        XCTAssertNil(RepoTree(parsing: Data(#"{"message":"API rate limit exceeded"}"#.utf8)))
        XCTAssertNil(RepoTree(parsing: Data("<html>".utf8)))
    }
}
