import XCTest
@testable import DevMonitorCore

final class MarketplaceFilesTests: XCTestCase {
    func testTheDeclaredVersionIsReadFromThePluginManifest() {
        let root = makeTempDirectory()
        write(root + "/plugins/tool/.claude-plugin/plugin.json", #"{"name":"tool","version":"2.0.9"}"#)
        write(root + "/.claude-plugin/plugin.json", #"{"name":"root"}"#)
        XCTAssertEqual(MarketplaceFiles.declaredVersion(in: root + "/plugins/tool"), "2.0.9")
        XCTAssertNil(MarketplaceFiles.declaredVersion(in: root))
        XCTAssertNil(MarketplaceFiles.declaredVersion(in: root + "/plugins/none"))
    }

    /// Creates an installed copy and a published copy of a plugin with the same two files, and returns both folders.
    /// @example let (installed, published) = makeCopies()
    private func makeCopies() -> (installed: String, published: String) {
        let root = makeTempDirectory()
        for copy in ["installed", "published"] {
            write(root + "/\(copy)/README.md", "hello")
            write(root + "/\(copy)/skills/audit/SKILL.md", "audit")
        }
        return (root + "/installed", root + "/published")
    }

    func testTheSameFilesAreTheSameWhateverTheBookkeeping() {
        let (installed, published) = makeCopies()
        write(installed + "/.in_use/1234", "")
        write(installed + "/hooks/__pycache__/x.pyc", "bytes")
        write(published + "/hooks/.DS_Store", "")
        try! FileManager.default.createDirectory(atPath: installed + "/hooks", withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(atPath: published + "/hooks", withIntermediateDirectories: true)
        write(published + "/.git/HEAD", "ref")
        XCTAssertEqual(MarketplaceFiles.sameFiles(installed, published), true)
    }

    func testAChangedAddedOrRemovedFileIsADifference() {
        var (installed, published) = makeCopies()
        write(published + "/skills/audit/SKILL.md", "AUDIT")
        XCTAssertEqual(MarketplaceFiles.sameFiles(installed, published), false)
        (installed, published) = makeCopies()
        write(published + "/skills/new/SKILL.md", "new")
        XCTAssertEqual(MarketplaceFiles.sameFiles(installed, published), false)
        (installed, published) = makeCopies()
        write(installed + "/old.md", "old")
        XCTAssertEqual(MarketplaceFiles.sameFiles(installed, published), false)
    }

    func testSymbolicLinksAreComparedByTargetAndNeverFollowed() throws {
        let (installed, published) = makeCopies()
        for copy in [installed, published] {
            try FileManager.default.createSymbolicLink(atPath: copy + "/skills/loop", withDestinationPath: "..")
        }
        XCTAssertEqual(MarketplaceFiles.sameFiles(installed, published), true)
        try FileManager.default.removeItem(atPath: published + "/skills/loop")
        try FileManager.default.createSymbolicLink(atPath: published + "/skills/loop", withDestinationPath: "audit")
        XCTAssertEqual(MarketplaceFiles.sameFiles(installed, published), false)
    }

    func testAMissingFolderCannotBeCompared() {
        let (installed, published) = makeCopies()
        XCTAssertNil(MarketplaceFiles.sameFiles(installed, published + "/nope"))
        XCTAssertNil(MarketplaceFiles.sameFiles(installed + "/README.md", published))
    }
}
