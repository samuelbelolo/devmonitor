import XCTest
@testable import DevMonitorCore
@testable import DevMonitorUI

final class StringsExtensionTests: XCTestCase {
    func testALongListOfNamesIsCutAfterThree() {
        let all = Strings.names(["a", "b", "c", "d", "e"])
        XCTAssertTrue(all.hasPrefix("a, b, c "))
        XCTAssertTrue(all.contains("2"))
        XCTAssertEqual(Strings.names(["a", "b", "c"]), "a, b, c")
        XCTAssertEqual(Strings.names(["a"]), "a")
    }

    func testEveryUnknownReasonHasASentence() {
        for reason in [UnknownReason.untracked, .notGitHub, .noAnswer, .noCatalog, .nothingToCompare, .unsafeName] {
            XCTAssertFalse(Strings.unknownReason(reason).isEmpty)
        }
    }

    func testCountsNameWhatTheyCount() {
        XCTAssertTrue(Strings.updates(1).hasPrefix("1 "))
        XCTAssertTrue(Strings.updates(27).hasPrefix("27 "))
        XCTAssertEqual(Strings.installed(85, sources: 11, kind: .skills), "85 · 11 sources")
        XCTAssertEqual(Strings.installed(22, sources: 1, kind: .plugins), "22 · 1 marketplace")
    }

    func testTheQuietLineSaysOtherOnlyUnderListedSources() {
        let under = Strings.quietSources(4, items: 23, kind: .skills, others: true, checked: true)
        let alone = Strings.quietSources(4, items: 23, kind: .skills, others: false, checked: true)
        XCTAssertTrue(under.hasPrefix("4 other sources") || under.hasPrefix("4 autres sources"))
        XCTAssertTrue(alone.hasPrefix("4 sources"))
        XCTAssertNotEqual(Strings.quietSources(1, items: 2, kind: .plugins, others: false, checked: false), Strings.quietSources(1, items: 2, kind: .plugins, others: false, checked: true))
    }
}
