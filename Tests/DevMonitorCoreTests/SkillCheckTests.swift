import XCTest
@testable import DevMonitorCore

final class SkillCheckTests: XCTestCase {
    private let tree = RepoTree(rootSHA: "root1", folders: ["skills/audit": "a1"], isTruncated: false)

    /// Returns a GitHub skill of `acme/kit` at a path, installed at a folder hash.
    /// @example skill("skills/audit/SKILL.md", "a1")
    private func skill(_ path: String?, _ hash: String?, type: String = "github") -> InstalledSkill {
        InstalledSkill(name: "audit", source: "acme/kit", sourceType: type, ref: nil, skillPath: path, folderHash: hash)
    }

    func testSameHashIsUpToDate() {
        XCTAssertEqual(SkillCheck.state(of: skill("skills/audit/SKILL.md", "a1"), in: tree), .upToDate)
    }

    func testAnotherHashIsAnUpdate() {
        XCTAssertEqual(SkillCheck.state(of: skill("skills/audit/SKILL.md", "old"), in: tree), .updateAvailable)
    }

    func testAMissingFolderIsMoved() {
        XCTAssertEqual(SkillCheck.state(of: skill(".claude/skills/audit/SKILL.md", "a1"), in: tree), .moved)
    }

    func testARootLevelSkillIsComparedWithTheRootTree() {
        XCTAssertEqual(SkillCheck.state(of: skill("SKILL.md", "root1"), in: tree), .upToDate)
        XCTAssertEqual(SkillCheck.state(of: skill("SKILL.md", "old"), in: tree), .updateAvailable)
    }

    func testWhatCannotBeComparedIsUnknown() {
        XCTAssertEqual(SkillCheck.state(of: skill(nil, "a1"), in: tree), .unknown(.untracked))
        XCTAssertEqual(SkillCheck.state(of: skill("skills/audit/SKILL.md", nil), in: tree), .unknown(.untracked))
        XCTAssertEqual(SkillCheck.state(of: skill("skills/audit/SKILL.md", "a1", type: "well-known"), in: tree), .unknown(.notGitHub))
        XCTAssertEqual(SkillCheck.state(of: skill("skills/audit/SKILL.md", "a1"), in: nil), .unknown(.noAnswer))
    }

    func testASkillUpdatedAfterTheTreeWasCheckedIsUpToDateUntilANewerTree() {
        let checked = Date(timeIntervalSince1970: 1_000)
        let old = tree.checked(at: checked)
        let after = InstalledSkill(
            name: "audit", source: "acme/kit", sourceType: "github", ref: nil, skillPath: "skills/audit/SKILL.md", folderHash: "a2",
            updatedAt: checked.addingTimeInterval(60))
        XCTAssertEqual(SkillCheck.state(of: after, in: old), .upToDate)
        // The tool may also have followed the skill to a folder the older tree does not hold.
        let followed = InstalledSkill(
            name: "audit", source: "acme/kit", sourceType: "github", ref: nil, skillPath: "plugins/audit/SKILL.md", folderHash: "a2",
            updatedAt: checked.addingTimeInterval(60))
        XCTAssertEqual(SkillCheck.state(of: followed, in: old), .upToDate)
        // Once GitHub vouches for a tree after the update, the hashes are compared again.
        XCTAssertEqual(SkillCheck.state(of: after, in: tree.checked(at: checked.addingTimeInterval(120))), .updateAvailable)
    }

    func testASkillUpdatedBeforeTheTreeWasCheckedIsCompared() {
        let checked = Date(timeIntervalSince1970: 1_000)
        let before = InstalledSkill(
            name: "audit", source: "acme/kit", sourceType: "github", ref: nil, skillPath: "skills/audit/SKILL.md", folderHash: "old",
            updatedAt: checked.addingTimeInterval(-60))
        XCTAssertEqual(SkillCheck.state(of: before, in: tree.checked(at: checked)), .updateAvailable)
    }

    func testATruncatedTreeIsOnlyInDoubtForTheFoldersItDoesNotShow() {
        let truncated = RepoTree(rootSHA: "r", folders: ["skills/audit": "a2"], isTruncated: true)
        XCTAssertEqual(SkillCheck.state(of: skill("skills/audit/SKILL.md", "a1"), in: truncated), .updateAvailable)
        XCTAssertEqual(SkillCheck.state(of: skill("skills/audit/SKILL.md", "a2"), in: truncated), .upToDate)
        XCTAssertEqual(SkillCheck.state(of: skill("skills/other/SKILL.md", "o1"), in: truncated), .unknown(.noAnswer))
    }
}
