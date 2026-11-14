import SwiftUI
import XCTest
@testable import DevMonitorUI

@MainActor
final class CopyCommandViewTests: XCTestCase {
    /// Returns the height a command takes in a window that gives it no more room than it insists on, as the agents
    /// window does once a list is expanded.
    /// @example height(of: "claude update") // one line
    private func height(of command: String) -> CGFloat {
        HostedView(sizedByContent: CopyCommandView(command: command), width: 320).height
    }

    /// Returns the command that updates `count` skills.
    /// @example update(2) // "npx skills update skill-number-0 skill-number-1 -g -y"
    private func update(_ count: Int) -> String {
        "npx skills update " + (0..<count).map { "skill-number-\($0)" }.joined(separator: " ") + " -g -y"
    }

    func testACommandThatDoesNotFitOnOneLineKeepsItsLines() {
        let oneLine = height(of: "claude update")
        // Seven names fill three lines: the window must not squeeze them back onto one.
        XCTAssertGreaterThan(height(of: update(7)), oneLine + 20)
    }

    func testACommandNeverTakesMoreThanThreeLines() {
        XCTAssertEqual(height(of: update(60)), height(of: update(12)), accuracy: 1)
    }
}
