import XCTest
@testable import DevMonitorCore

final class StopRequestsTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)
    private let launcher = snap(40, parent: 1, path: "/bin/pnpm")
    private let worker = snap(50, parent: 40, path: "/bin/node")

    func testServiceHasNoRequestUntilOneIsRecorded() {
        XCTAssertNil(StopRequests().date(for: service([launcher, worker])))
    }

    func testRecordedRequestIsFoundForTheService() {
        var requests = StopRequests()
        requests.record([service([launcher, worker])], at: start)
        XCTAssertEqual(requests.date(for: service([launcher, worker])), start)
    }

    func testChildThatOutlivesItsParentKeepsTheRequest() {
        var requests = StopRequests()
        requests.record([service([launcher, worker])], at: start)
        requests.prune(keeping: [worker.identity])
        XCTAssertEqual(requests.date(for: service([worker])), start)
    }

    func testSecondRequestKeepsTheDateOfTheFirst() {
        var requests = StopRequests()
        requests.record([service([launcher])], at: start)
        requests.record([service([launcher])], at: start + 30)
        XCTAssertEqual(requests.date(for: service([launcher])), start)
    }

    func testRequestIsForgottenOnceItsProcessIsGone() {
        var requests = StopRequests()
        requests.record([service([launcher])], at: start)
        requests.prune(keeping: [])
        XCTAssertNil(requests.date(for: service([launcher])))
    }
}
