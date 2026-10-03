import XCTest
@testable import DevMonitorCore

final class InstalledAgentsTests: XCTestCase {
    func testVersionManagersAndTheInheritedPathAreSearched() {
        let folders = InstalledAgents.searchFolders(home: "/Users/me", inheritedPath: "/usr/bin:/opt/homebrew/bin", nvmVersions: ["v20.1.0", "v22.11.0", ".DS_Store"])
        XCTAssertEqual(folders.first, "/Users/me/.local/bin")
        XCTAssertTrue(folders.contains("/Users/me/.n/bin"))
        XCTAssertTrue(folders.contains("/Users/me/.volta/bin"))
        let nvm = folders.filter { $0.contains("/.nvm/") }
        XCTAssertEqual(nvm, ["/Users/me/.nvm/versions/node/v22.11.0/bin", "/Users/me/.nvm/versions/node/v20.1.0/bin"])
        XCTAssertEqual(folders.last, "/usr/bin")
        XCTAssertEqual(folders.filter { $0 == "/opt/homebrew/bin" }.count, 1)
    }

    func testProbeFindsTheInterpreterInstalledBesideTheCommand() {
        let environment = InstalledAgents.probeEnvironment(for: "/Users/me/.n/bin/codex", folders: ["/Users/me/.local/bin"], base: ["PATH": "/usr/bin:/bin", "HOME": "/Users/me"])
        XCTAssertEqual(environment["PATH"], "/Users/me/.n/bin:/Users/me/.local/bin:/usr/bin:/bin")
        XCTAssertEqual(environment["HOME"], "/Users/me")
    }
}
