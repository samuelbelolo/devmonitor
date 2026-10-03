import XCTest
@testable import DevMonitorCore

final class AppLanguageTests: XCTestCase {
    func testLanguageIsFrenchOnlyWhenTheFirstPreferredLanguageIsFrench() {
        XCTAssertEqual(AppLanguage.preferred(among: ["fr-FR", "en-US"]), .french)
        XCTAssertEqual(AppLanguage.preferred(among: ["en-GB", "fr-FR"]), .english)
        XCTAssertEqual(AppLanguage.preferred(among: []), .english)
    }
}
