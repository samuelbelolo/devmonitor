import XCTest
@testable import DevMonitorCore

final class MarketplacesTests: XCTestCase {
    private let known = Data(#"""
    {"official":{"installLocation":"/m/official","lastUpdated":"2026-10-05T15:32:58.748Z"},
     "empty":{"installLocation":"/m/empty"}}
    """#.utf8)
    private let catalog = Data(#"""
    {"plugins":[
      {"name":"figma","source":{"source":"url","url":"https://x","sha":"1729"}},
      {"name":"feature-dev","source":"./plugins/feature-dev"},
      {"name":"typed","version":"1.0.0","source":"./"},
      {"name":"odd","source":{"source":"github","repo":"a/b"}}]}
    """#.utf8)

    func testCatalogEntriesAreReadWithTheirSource() {
        let all = Marketplaces.read(known: known) { $0 == "/m/official/.claude-plugin/marketplace.json" ? self.catalog : nil }
        let official = all["official"]
        XCTAssertEqual(official?.location, "/m/official")
        XCTAssertEqual(official?.entries["figma"]?.source, .pinned(sha: "1729"))
        XCTAssertEqual(official?.entries["feature-dev"]?.source, .relative(path: "plugins/feature-dev"))
        XCTAssertEqual(official?.entries["typed"], Marketplace.Entry(version: "1.0.0", source: .relative(path: "")))
        XCTAssertEqual(official?.entries["odd"]?.source, .other)
        XCTAssertEqual(official?.folder(of: "plugins/feature-dev"), "/m/official/plugins/feature-dev")
        XCTAssertEqual(official?.folder(of: ""), "/m/official")
    }

    func testTheLastRefreshIsADate() {
        let official = Marketplaces.read(known: known) { _ in nil }["official"]
        XCTAssertEqual(official?.lastUpdated?.timeIntervalSince1970 ?? 0, 1_791_214_378.748, accuracy: 0.01)
    }

    func testAMarketplaceWithoutACatalogHasNoEntry() {
        let empty = Marketplaces.read(known: known) { _ in nil }["empty"]
        XCTAssertEqual(empty?.entries, [:])
        XCTAssertNil(empty?.lastUpdated)
    }

    func testGarbageGivesNoMarketplace() {
        XCTAssertTrue(Marketplaces.read(known: Data("x".utf8)) { _ in nil }.isEmpty)
    }
}
