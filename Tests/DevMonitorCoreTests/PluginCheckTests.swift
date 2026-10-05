import XCTest
@testable import DevMonitorCore

final class PluginCheckTests: XCTestCase {
    /// Returns a marketplace at `/m` whose catalog has one plugin, `tool`, with the given entry.
    /// @example market(.pinned(sha: "new"))
    private func market(_ source: Marketplace.Source, version: String? = nil) -> Marketplace {
        Marketplace(name: "acme", location: "/m", lastUpdated: nil, entries: ["tool": Marketplace.Entry(version: version, source: source)])
    }

    /// Returns the state of `tool@acme` installed at a version and commit, with scripted disk answers.
    /// @example state(sha: "old", in: market(.pinned(sha: "new"))) // .updateAvailable
    private func state(version: String? = "1.0.0", sha: String? = "old", path: String? = "/cache/tool", in marketplace: Marketplace?, declared: String? = nil, same: Bool? = nil) -> ExtensionState {
        let plugin = InstalledPlugin(name: "tool", marketplace: "acme", scope: "user", version: version, commitSHA: sha, installPath: path)
        return PluginCheck.state(of: plugin, in: marketplace, declaredVersion: { $0 == "/m/p" ? declared : nil }) { installed, published in
            installed == "/cache/tool" && published == "/m/p" ? same : nil
        }
    }

    func testAPinnedSourceIsComparedByCommit() {
        XCTAssertEqual(state(sha: "old", in: market(.pinned(sha: "new"))), .updateAvailable)
        XCTAssertEqual(state(sha: "new", in: market(.pinned(sha: "new"))), .upToDate)
        XCTAssertEqual(state(sha: nil, in: market(.pinned(sha: "new"))), .unknown(.nothingToCompare))
    }

    func testAPinnedSourceWithACatalogVersionIsComparedByVersion() {
        XCTAssertEqual(state(version: "1.0.0", sha: "old", in: market(.pinned(sha: "new"), version: "1.0.0")), .upToDate)
        XCTAssertEqual(state(version: "1.0.0", sha: "same", in: market(.pinned(sha: "same"), version: "1.1.0")), .updateAvailable)
    }

    func testThePluginManifestWinsOverTheCatalog() {
        XCTAssertEqual(state(version: "1.0.0", in: market(.relative(path: "p"), version: "1.0.0"), declared: "2.0.0"), .updateAvailable)
        XCTAssertEqual(state(version: "2.0.0", in: market(.relative(path: "p"), version: "1.0.0"), declared: "2.0.0"), .upToDate)
    }

    func testADeclaredVersionIsComparedByInequality() {
        XCTAssertEqual(state(version: "1.0.0", in: market(.relative(path: "p"), version: "1.1.0")), .updateAvailable)
        XCTAssertEqual(state(version: "1.0.0", in: market(.relative(path: "p"), version: "1.0.0")), .upToDate)
        XCTAssertEqual(state(version: "1.0.0", in: market(.relative(path: "p")), declared: "0.9.0"), .updateAvailable)
        XCTAssertEqual(state(version: "1.0.0", in: market(.relative(path: "p")), declared: "1.0.0", same: false), .upToDate)
    }

    func testWithoutAVersionTheFilesDecide() {
        XCTAssertEqual(state(in: market(.relative(path: "p")), same: false), .updateAvailable)
        XCTAssertEqual(state(in: market(.relative(path: "p")), same: true), .upToDate)
        XCTAssertEqual(state(sha: nil, in: market(.relative(path: "p")), same: true), .upToDate)
    }

    func testNothingToCompareIsUnknown() {
        XCTAssertEqual(state(in: market(.relative(path: "p")), same: nil), .unknown(.nothingToCompare))
        XCTAssertEqual(state(path: nil, in: market(.relative(path: "p")), same: true), .unknown(.nothingToCompare))
        XCTAssertEqual(state(in: market(.other)), .unknown(.nothingToCompare))
    }

    func testAMissingMarketplaceOrEntryIsUnknown() {
        XCTAssertEqual(state(in: nil), .unknown(.noCatalog))
        let other = Marketplace(name: "acme", location: "/m", lastUpdated: nil, entries: [:])
        XCTAssertEqual(state(in: other), .unknown(.noCatalog))
    }
}
