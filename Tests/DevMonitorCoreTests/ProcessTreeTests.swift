import XCTest
@testable import DevMonitorCore

final class ProcessTreeTests: XCTestCase {
    func testDescendantsListsChildrenBeforeGrandchildren() {
        let tree = ProcessTree(agentChain())
        XCTAssertEqual(tree.descendants(of: 30).map(\.pid), [40, 50])
    }

    func testAncestorsStartWithTheNearestParent() {
        let tree = ProcessTree(agentChain())
        XCTAssertEqual(tree.ancestors(of: 50).map(\.pid), [40, 30, 20, 10])
    }

    func testAncestorsStopOnAParentCycle() {
        let tree = ProcessTree([snap(1, parent: 2, path: "/a"), snap(2, parent: 1, path: "/b")])
        XCTAssertEqual(tree.ancestors(of: 1).map(\.pid), [2])
    }
}
