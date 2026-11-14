import DevMonitorCore
import SwiftUI
import XCTest
@testable import DevMonitorUI

@MainActor
final class ExtensionKindViewTests: XCTestCase {
    /// Returns a repository of skills with one outdated skill, which the list shows as a line of its own.
    /// @example source("acme/kit").updates // 1
    private func source(_ name: String) -> ExtensionSource {
        let item = ExtensionItem(id: name, name: "audit", detail: nil, state: .updateAvailable, command: nil)
        return ExtensionSource(kind: .skills, name: name, items: [item], command: ExtensionCommand.updateSkills(["audit"]))
    }

    /// Hosts the list of these sources in a window that follows its height both ways, as the agents window does.
    /// @example hosted(sources).height // 22
    private func hosted(_ sources: [ExtensionSource]) -> HostedView {
        HostedView(sizedByContent: ExtensionKindView(kind: .skills, sources: sources).font(.system(size: 12.5)).background(WindowFit()), width: 332)
    }

    func testAnOpenListGrowsTheWindowInsteadOfScrollingInside() {
        // Twenty lines are taller than the 300 points the list once scrolled in, a bar taking 17 points off each line.
        let hosted = hosted((0..<20).map { source("acme/kit-\($0)") })
        let closed = hosted.height
        hosted.click(x: 120, y: 12)
        XCTAssertEqual(hosted.scrollViews.count, 0)
        XCTAssertGreaterThan(hosted.height, closed + 400)
    }

    func testExpandingASourceFoldsTheOneThatWasExpanded() {
        let hosted = hosted((0..<6).map { source("acme/kit-\($0)") })
        let closed = hosted.height
        hosted.click(x: 120, y: 12)
        let open = hosted.height
        // The lines are evenly spaced under the header: the middle of line `index`, from the top of the view.
        let pitch = (open - closed) / 6
        let middle = { (index: CGFloat) in closed + pitch * (index + 0.5) }
        hosted.click(x: 120, y: middle(0))
        let oneExpanded = hosted.height
        XCTAssertGreaterThan(oneExpanded, open + 20)
        // The fourth line sits lower by what the first one shows once expanded.
        hosted.click(x: 120, y: middle(3) + oneExpanded - open)
        XCTAssertEqual(hosted.height, oneExpanded, accuracy: 1)
        // The first line is folded again, so the fourth one is back at its place: a click there folds it too.
        hosted.click(x: 120, y: middle(3))
        XCTAssertEqual(hosted.height, open, accuracy: 1)
    }
}
