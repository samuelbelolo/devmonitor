import XCTest
@testable import DevMonitorCore

final class InstalledPluginsTests: XCTestCase {
    func testEveryInstallRecordIsRead() {
        let json = Data(#"""
        {"version":2,"plugins":{
          "figma@claude-plugins-official":[{"scope":"user","version":"2.2.120","gitCommitSha":"1729"}],
          "@scope/tool@acme":[{"scope":"user","version":"1.0.0"},{"scope":"project","version":"0.9.0","gitCommitSha":"abcd","installPath":"/cache/tool/0.9.0","projectPath":"/p/shop"}]
        }}
        """#.utf8)
        let plugins = InstalledPlugins.plugins(from: json)
        XCTAssertEqual(plugins.map(\.id), ["@scope/tool@acme project /p/shop", "@scope/tool@acme user", "figma@claude-plugins-official user"])
        XCTAssertEqual(plugins[0].name, "@scope/tool")
        XCTAssertEqual(plugins[0].marketplace, "acme")
        XCTAssertEqual(plugins[0].commitSHA, "abcd")
        XCTAssertEqual(plugins[0].installPath, "/cache/tool/0.9.0")
        XCTAssertNil(plugins[1].commitSHA)
        XCTAssertEqual(plugins[2].pluginID, "figma@claude-plugins-official")
    }

    func testGarbageGivesNoPlugin() {
        XCTAssertEqual(InstalledPlugins.plugins(from: Data("nope".utf8)), [])
        XCTAssertEqual(InstalledPlugins.plugins(from: Data(#"{"plugins":{"no-marketplace":[{}],"x@y":"oops"}}"#.utf8)), [])
    }
}
