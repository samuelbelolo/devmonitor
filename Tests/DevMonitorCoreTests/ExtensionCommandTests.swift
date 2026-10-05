import XCTest
@testable import DevMonitorCore

final class ExtensionCommandTests: XCTestCase {
    /// Returns a plugin with the given name, marketplace and scope.
    /// @example plugin("figma", "official")
    private func plugin(_ name: String, _ marketplace: String, scope: String = "user") -> InstalledPlugin {
        InstalledPlugin(name: name, marketplace: marketplace, scope: scope, version: nil, commitSHA: nil)
    }

    func testSeveralSkillsShareOneCommand() {
        XCTAssertEqual(ExtensionCommand.updateSkills(["audit", "find-skills"]), "npx skills update audit find-skills -g -y")
        XCTAssertNil(ExtensionCommand.updateSkills([]))
    }

    func testAPluginIsUpdatedByItsId() {
        XCTAssertEqual(ExtensionCommand.updatePlugin(plugin("figma", "claude-plugins-official")), "claude plugin update figma@claude-plugins-official --scope user")
        XCTAssertEqual(ExtensionCommand.updatePlugin(plugin("figma", "official", scope: "project")), "claude plugin update figma@official --scope project")
    }

    func testUnsafeNamesNeverReachACommand() {
        XCTAssertEqual(ExtensionCommand.updateSkills(["audit", "x; rm -rf ~", "-g", "$(id)", "a b"]), "npx skills update audit -g -y")
        XCTAssertNil(ExtensionCommand.updateSkills(["`id`"]))
        XCTAssertNil(ExtensionCommand.updatePlugin(plugin("figma", "x && id")))
        XCTAssertNil(ExtensionCommand.updatePlugin(plugin("figma", "official", scope: "user; id")))
    }

    func testMarketplacesAreRefreshedTogether() {
        XCTAssertEqual(ExtensionCommand.refreshMarketplaces, "claude plugin marketplace update")
    }
}
