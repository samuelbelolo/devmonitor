import XCTest
@testable import DevMonitorCore

final class PktLineTests: XCTestCase {
    func testALineCountsItsOwnLength() {
        XCTAssertEqual(PktLine.encode("command=ls-refs\n"), "0014command=ls-refs\n")
        XCTAssertEqual(PktLine.encode("peel\n"), "0009peel\n")
    }

    func testLinesAreReadUntilTheEndSkippingFlushAndDelimiter() {
        let data = Data("0009abcd\n00010006xy0000".utf8)
        XCTAssertEqual(PktLine.lines(in: data), ["abcd", "xy"])
    }

    func testReadingStopsAtALineThatIsCutShortOrNotFramed() {
        XCTAssertEqual(PktLine.lines(in: Data("0009abcd\n0020short".utf8)), ["abcd"])
        XCTAssertEqual(PktLine.lines(in: Data("<html>".utf8)), [])
    }
}
