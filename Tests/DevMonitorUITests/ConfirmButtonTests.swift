import SwiftUI
import XCTest
@testable import DevMonitorUI

@MainActor
final class ConfirmButtonTests: XCTestCase {
    private var runs = 0

    /// Hosts a row-like line, 200 points wide, whose last 18 points hold the icon button.
    /// @example iconRow().click(x: 191, y: 15)
    private func iconRow() -> HostedView {
        let row = HStack(spacing: 0) {
            Text("serena").frame(maxWidth: .infinity, alignment: .leading)
            ConfirmButton(title: "Stop", systemImage: "xmark.circle.fill") { [unowned self] in self.runs += 1 }
                .frame(width: 18, height: 18)
        }
        return HostedView(row, width: 200, height: 30)
    }

    func testTextButtonRunsItsActionOnTheSecondClick() {
        let hosted = HostedView(ConfirmButton(title: "Stop") { [unowned self] in self.runs += 1 }, width: 120, height: 30)
        hosted.click(x: 60, y: 15)
        XCTAssertEqual(runs, 0)
        hosted.click(x: 60, y: 15)
        XCTAssertEqual(runs, 1)
    }

    func testIconButtonRunsItsActionWhenTheSecondClickStaysOnTheIcon() {
        let hosted = iconRow()
        hosted.click(x: 191, y: 15)
        XCTAssertEqual(runs, 0)
        hosted.click(x: 191, y: 15)
        XCTAssertEqual(runs, 1)
    }

    func testIconButtonRunsItsActionWhenTheSecondClickIsOnTheConfirmLabel() {
        let hosted = iconRow()
        hosted.click(x: 191, y: 15)
        hosted.click(x: 160, y: 15)
        XCTAssertEqual(runs, 1)
    }
}
