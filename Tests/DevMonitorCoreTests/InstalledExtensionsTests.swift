import XCTest
@testable import DevMonitorCore

final class InstalledExtensionsTests: XCTestCase {
    func testEverythingIsReadFromTheHomeFolder() {
        let files = [
            "/h/.agents/.skill-lock.json": #"{"skills":{"audit":{"source":"acme/kit","sourceType":"github","skillPath":"skills/audit/SKILL.md","skillFolderHash":"a1"}}}"#,
            "/h/.claude/plugins/installed_plugins.json": #"{"plugins":{"figma@official":[{"scope":"user","version":"1","gitCommitSha":"old"}]}}"#,
            "/h/.claude/plugins/known_marketplaces.json": #"{"official":{"installLocation":"/m/official"}}"#,
            "/m/official/.claude-plugin/marketplace.json": #"{"plugins":[{"name":"figma","source":{"sha":"new"}}]}"#,
        ]
        let installed = InstalledExtensions.read(home: "/h") { files[$0].map { Data($0.utf8) } }
        XCTAssertEqual(installed.skillSources, [SkillSource(repo: "acme/kit", ref: nil)])
        let tree = RepoTree(rootSHA: "r", folders: ["skills/audit": "a2"], isTruncated: false)
        let report = installed.report(trees: [SkillSource(repo: "acme/kit", ref: nil): tree], checksUpstream: true, now: Date())
        XCTAssertEqual(ExtensionReport.updates(in: report.skills), 1)
        XCTAssertEqual(ExtensionReport.updates(in: report.plugins), 1)
        XCTAssertEqual(ExtensionReport.count(in: report.plugins), 1)
        XCTAssertFalse(report.isEmpty)
    }

    func testMissingFilesGiveAnEmptyReport() {
        let installed = InstalledExtensions.read(home: "/nowhere") { _ in nil }
        XCTAssertTrue(installed.skillSources.isEmpty)
        XCTAssertTrue(installed.report(trees: [:], checksUpstream: true, now: Date()).isEmpty)
        XCTAssertTrue(ExtensionReport.empty.isEmpty)
    }
}
