import XCTest
@testable import DevMonitorCore

final class SkillSourcesTests: XCTestCase {
    /// Returns a GitHub skill of a repository, at `skills/<name>/SKILL.md`.
    /// @example skill("audit", "acme/kit", "a1")
    private func skill(_ name: String, _ repo: String, _ hash: String) -> InstalledSkill {
        InstalledSkill(name: name, source: repo, sourceType: "github", ref: nil, skillPath: "skills/\(name)/SKILL.md", folderHash: hash)
    }

    private var skills: [InstalledSkill] {
        [skill("audit", "acme/kit", "old"), skill("polish", "acme/kit", "p1"), skill("gone", "acme/kit", "g1"),
         skill("fine", "quiet/repo", "f1"), InstalledSkill(name: "notion", source: "notion", sourceType: "well-known", ref: nil, skillPath: nil, folderHash: nil)]
    }

    private let trees = [
        SkillSource(repo: "acme/kit", ref: nil): RepoTree(rootSHA: "r", folders: ["skills/audit": "a2", "skills/polish": "p1"], isTruncated: false),
        SkillSource(repo: "quiet/repo", ref: nil): RepoTree(rootSHA: "r", folders: ["skills/fine": "f1"], isTruncated: false),
    ]

    func testSkillsAreGroupedBySourceWithTheirStates() {
        let sources = SkillSources.sources(for: skills, trees: trees, checksUpstream: true)
        XCTAssertEqual(sources.map(\.name), ["acme/kit", "notion", "quiet/repo"])
        XCTAssertEqual(sources[0].items.map(\.state), [.updateAvailable, .moved, .upToDate])
        XCTAssertEqual([sources[0].updates, sources[0].moved, sources[0].unknown], [1, 1, 0])
        XCTAssertEqual(sources[0].command, "npx skills update audit -g -y")
        XCTAssertEqual(sources[1].unknownReason, .untracked)
        XCTAssertFalse(sources[2].needsAttention)
        XCTAssertNil(sources[2].command)
    }

    func testWithTheCheckOffNothingNeedsAttention() {
        let sources = SkillSources.sources(for: skills, trees: [:], checksUpstream: false)
        XCTAssertEqual(sources.count, 3)
        XCTAssertFalse(sources.contains(where: \.needsAttention))
        XCTAssertEqual(sources[0].items[0].state, .notChecked)
        XCTAssertNil(sources[0].unknownReason)
        XCTAssertFalse(sources[0].isChecked)
        XCTAssertTrue(SkillSources.sources(for: skills, trees: trees, checksUpstream: true)[2].isChecked)
    }

    func testARepositoryThatDidNotAnswerIsUnknown() {
        let sources = SkillSources.sources(for: [skill("audit", "acme/kit", "old")], trees: [:], checksUpstream: true)
        XCTAssertEqual(sources[0].unknownReason, .noAnswer)
        XCTAssertEqual(sources[0].unknown, 1)
    }

    func testAnUpdateWhoseNameCannotGoIntoACommandIsUnknown() {
        let odd = InstalledSkill(name: "x; rm -rf ~", source: "acme/kit", sourceType: "github", ref: nil, skillPath: "skills/audit/SKILL.md", folderHash: "old")
        let source = SkillSources.sources(for: [odd, skill("audit", "acme/kit", "old")], trees: trees, checksUpstream: true)[0]
        XCTAssertEqual(source.items.map(\.state), [.updateAvailable, .unknown(.unsafeName)])
        XCTAssertEqual(source.updates, 1)
        XCTAssertEqual(source.command, "npx skills update audit -g -y")
    }

    func testSourcesWithMoreUpdatesComeFirst() {
        let one = ExtensionSource(kind: .skills, name: "a", items: [ExtensionItem(id: "1", name: "1", detail: nil, state: .updateAvailable, command: nil)], command: nil)
        let none = ExtensionSource(kind: .skills, name: "0", items: [ExtensionItem(id: "2", name: "2", detail: nil, state: .upToDate, command: nil)], command: nil)
        let moved = ExtensionSource(kind: .skills, name: "z", items: [ExtensionItem(id: "3", name: "3", detail: nil, state: .moved, command: nil)], command: nil)
        XCTAssertEqual(ExtensionSource.inDisplayOrder([none, moved, one]).map(\.name), ["a", "z", "0"])
    }
}
