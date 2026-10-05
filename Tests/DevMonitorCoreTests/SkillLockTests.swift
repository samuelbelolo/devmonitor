import XCTest
@testable import DevMonitorCore

final class SkillLockTests: XCTestCase {
    private let lock = Data(#"""
    {"version":3,"skills":{
      "find-skills":{"source":"vercel-labs/skills","sourceType":"github","skillPath":"skills/find-skills/SKILL.md","skillFolderHash":"c2f3"},
      "audit":{"source":"acme/kit","sourceType":"github","ref":"v2","skillPath":".claude/skills/audit/SKILL.md","skillFolderHash":"aa11"},
      "notion":{"source":"notion","sourceType":"well-known"},
      "broken":{"source":"acme/kit","sourceType":"github","skillPath":"skills/broken/SKILL.md","skillFolderHash":""}
    }}
    """#.utf8)

    func testSkillsAreReadInNameOrder() {
        let skills = SkillLock.skills(from: lock)
        XCTAssertEqual(skills.map(\.name), ["audit", "broken", "find-skills", "notion"])
        XCTAssertEqual(skills[2].folderHash, "c2f3")
        XCTAssertEqual(skills[2].skillPath, "skills/find-skills/SKILL.md")
    }

    func testARefIsPartOfTheSource() {
        let audit = SkillLock.skills(from: lock)[0]
        XCTAssertEqual(audit.gitHubSource, SkillSource(repo: "acme/kit", ref: "v2"))
        XCTAssertEqual(audit.gitHubSource?.name, "acme/kit@v2")
    }

    func testAnEmptyHashAndANonGitHubSourceAreKeptAsMissing() {
        let skills = SkillLock.skills(from: lock)
        XCTAssertNil(skills[1].folderHash)
        XCTAssertNil(skills[3].gitHubSource)
    }

    func testGarbageGivesNoSkill() {
        XCTAssertEqual(SkillLock.skills(from: Data("not json".utf8)), [])
        XCTAssertEqual(SkillLock.skills(from: Data(#"{"skills":[1,2]}"#.utf8)), [])
        XCTAssertEqual(SkillLock.skills(from: Data()), [])
    }

    func testTheTreeAddressNamesTheRepositoryAndTheRef() {
        XCTAssertEqual(SkillSource(repo: "acme/kit", ref: nil).treeURL?.absoluteString, "https://api.github.com/repos/acme/kit/git/trees/HEAD?recursive=1")
        XCTAssertEqual(SkillSource(repo: "acme/kit", ref: "feat/x").treeURL?.absoluteString, "https://api.github.com/repos/acme/kit/git/trees/feat%2Fx?recursive=1")
        XCTAssertNil(SkillSource(repo: "acme/kit/../../users", ref: nil).treeURL)
        XCTAssertNil(SkillSource(repo: "acme kit", ref: nil).treeURL)
    }
}
