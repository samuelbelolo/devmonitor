import XCTest
@testable import DevMonitorCore

final class PluginSourcesTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let plugins = [
        InstalledPlugin(name: "figma", marketplace: "official", scope: "user", version: "2.2.120", commitSHA: "old"),
        InstalledPlugin(name: "posthog", marketplace: "official", scope: "project", version: "1.1.64", commitSHA: "same", projectPath: "/Users/me/acme/shop"),
        InstalledPlugin(name: "brag", marketplace: "brag", scope: "user", version: "0.4.0", commitSHA: "b"),
    ]

    /// Returns the two marketplaces, last refreshed some days before `now`.
    /// @example marketplaces(officialAge: 1, bragAge: 8)
    private func marketplaces(officialAge: Double, bragAge: Double?) -> [String: Marketplace] {
        let official = Marketplace(name: "official", location: "/m/official", lastUpdated: now.addingTimeInterval(-officialAge * 86_400), entries: [
            "figma": Marketplace.Entry(version: nil, source: .pinned(sha: "new")),
            "posthog": Marketplace.Entry(version: nil, source: .pinned(sha: "same")),
        ])
        let brag = Marketplace(name: "brag", location: "/m/brag", lastUpdated: bragAge.map { now.addingTimeInterval(-$0 * 86_400) }, entries: [:])
        return ["official": official, "brag": brag, "unused": Marketplace(name: "unused", location: "/m/u", lastUpdated: .distantPast, entries: [:])]
    }

    func testPluginsAreGroupedByMarketplaceWithTheirCommand() {
        let sources = PluginSources.sources(for: plugins, marketplaces: marketplaces(officialAge: 1, bragAge: 1))
        XCTAssertEqual(sources.map(\.name), ["official", "brag"])
        XCTAssertEqual(sources[0].items.map(\.name), ["figma", "posthog"])
        XCTAssertEqual(sources[0].items[0].command, "claude plugin update figma@official --scope user")
        XCTAssertEqual(sources[0].items[0].detail, "2.2.120")
        XCTAssertNil(sources[0].items[1].command)
        XCTAssertEqual(sources[0].items[1].detail, "1.1.64 · project · shop")
        XCTAssertNil(sources[0].command)
        XCTAssertEqual(sources[1].unknownReason, .noCatalog)
    }

    func testTwoProjectInstallsOfOnePluginAreTwoLines() {
        let twice = ["/p/a", "/p/b"].map { InstalledPlugin(name: "figma", marketplace: "official", scope: "local", version: "1", commitSHA: "old", projectPath: $0) }
        let items = PluginSources.sources(for: twice, marketplaces: marketplaces(officialAge: 1, bragAge: 1))[0].items
        XCTAssertEqual(Set(items.map(\.id)).count, 2)
        XCTAssertEqual(items.map(\.detail), ["1 · local · a", "1 · local · b"])
        XCTAssertEqual(items[0].command, "claude plugin update figma@official --scope local")
    }

    func testAnUpdateWhoseIdCannotGoIntoACommandIsUnknown() {
        let odd = InstalledPlugin(name: "figma", marketplace: "official", scope: "user; id", version: "1", commitSHA: "old")
        let item = PluginSources.sources(for: [odd], marketplaces: marketplaces(officialAge: 1, bragAge: 1))[0].items[0]
        XCTAssertEqual(item.state, .unknown(.unsafeName))
        XCTAssertNil(item.command)
    }

    func testOnlyOldCatalogsOfInstalledPluginsAreStale() {
        XCTAssertEqual(PluginSources.staleCatalogs(for: plugins, marketplaces: marketplaces(officialAge: 1, bragAge: 8), now: now), 1)
        XCTAssertEqual(PluginSources.staleCatalogs(for: plugins, marketplaces: marketplaces(officialAge: 7.5, bragAge: 30), now: now), 2)
        XCTAssertEqual(PluginSources.staleCatalogs(for: plugins, marketplaces: marketplaces(officialAge: 6.9, bragAge: nil), now: now), 0)
    }
}
