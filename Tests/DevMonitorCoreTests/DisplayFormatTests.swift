import XCTest
@testable import DevMonitorCore

final class DisplayFormatTests: XCTestCase {
    func testMemoryBelowOneGigabyteIsShownInMegabytes() {
        XCTAssertEqual(DisplayFormat.memory(160 * 1_048_576, language: .french), "160 Mo")
        XCTAssertEqual(DisplayFormat.memory(160 * 1_048_576, language: .english), "160 MB")
    }

    func testFrenchMemoryAboveOneGigabyteUsesADecimalComma() {
        XCTAssertEqual(DisplayFormat.memory(2_362_232_012, language: .french), "2,2 Go")
    }

    func testEnglishMemoryAboveOneGigabyteUsesADecimalPoint() {
        XCTAssertEqual(DisplayFormat.memory(2_362_232_012, language: .english), "2.2 GB")
    }

    func testDurationUsesTheLargestUnit() {
        XCTAssertEqual(DisplayFormat.duration(seconds: 720, language: .french), "12 min")
        XCTAssertEqual(DisplayFormat.duration(seconds: 13 * 3600 + 40 * 60, language: .french), "13 h")
        XCTAssertEqual(DisplayFormat.duration(seconds: 4 * 86_400 + 5, language: .french), "4 j")
    }

    func testEnglishDaysAreAbbreviatedWithD() {
        XCTAssertEqual(DisplayFormat.duration(seconds: 4 * 86_400 + 5, language: .english), "4 d")
    }
}
