import DevMonitorCore
import XCTest

/// The answers below are written by hand from the shape of a real one: only the keys the reader uses, with made-up
/// figures and dates.
final class ClaudeUsageAnswerTests: XCTestCase {
    private let reset = "2026-11-21T04:00:00.302782+00:00"

    /// Returns the usage read from an answer written as JSON text.
    /// @example usage(#"{"limits": []}"#).limits // []
    private func usage(_ json: String) throws -> AccountUsage {
        try ClaudeUsageAnswer.usage(from: Data(json.utf8))
    }

    /// Returns one entry of `limits[]`, its model named when given.
    /// @example limit("weekly_all", 40) // {"kind": "weekly_all", "percent": 40, …}
    private func limit(_ kind: String, _ percent: Double, model: String? = nil) -> String {
        let scope = model.map { #"{"model": {"id": null, "display_name": "\#($0)"}, "surface": null}"# } ?? "null"
        return #"{"kind": "\#(kind)", "group": "weekly", "percent": \#(percent), "resets_at": "\#(reset)", "scope": \#(scope)}"#
    }

    func testTheWeekAndTheWeekOnAModelAreReadFromTheLimits() throws {
        let read = try usage(#"{"five_hour": null, "limits": [\#(limit("weekly_all", 40)), \#(limit("weekly_scoped", 62, model: "Fable"))]}"#)
        XCTAssertEqual(read.limits.map(\.kind), [.week, .weekOnModel("Fable")])
        XCTAssertEqual(read.limits.map(\.percentUsed), [40, 62])
        let expected = Date(timeIntervalSince1970: 1_795_233_600.302782)
        XCTAssertEqual(read.limits[0].resetsAt?.timeIntervalSince1970 ?? 0, expected.timeIntervalSince1970, accuracy: 0.001)
    }

    func testTheRoomIsWhatTheFullestLimitLeaves() throws {
        let read = try usage(#"{"limits": [\#(limit("weekly_all", 40)), \#(limit("weekly_scoped", 62, model: "Fable"))]}"#)
        XCTAssertEqual(read.fullest?.kind, .weekOnModel("Fable"))
        XCTAssertEqual(read.room, 38)
    }

    func testTheLimitsWinOverTheSevenDayFigureWhenTheyDisagree() throws {
        let read = try usage(#"{"seven_day": {"utilization": 90.0, "resets_at": "\#(reset)"}, "limits": [\#(limit("weekly_all", 40))]}"#)
        XCTAssertEqual(read.limits.map(\.kind), [.week])
        XCTAssertEqual(read.limits.map(\.percentUsed), [40])
    }

    func testTheSevenDayFigureGivesTheWeekWhenNoLimitIsListed() throws {
        for limits in ["", #", "limits": []"#, #", "limits": null"#] {
            let read = try usage(#"{"seven_day": {"utilization": 55.5, "resets_at": "\#(reset)"}\#(limits)}"#)
            XCTAssertEqual(read.limits.map(\.kind), [.week], limits)
            XCTAssertEqual(read.limits.map(\.percentUsed), [55.5], limits)
        }
    }

    func testANullFiveHourLimitIsLeftOutAndAGivenOneIsKept() throws {
        XCTAssertEqual(try usage(#"{"five_hour": null, "limits": [\#(limit("weekly_all", 10))]}"#).limits.count, 1)
        let read = try usage(#"{"five_hour": {"utilization": 75.0, "resets_at": "2026-11-14T20:00:00+00:00"}, "limits": [\#(limit("weekly_all", 10))]}"#)
        XCTAssertEqual(read.limits.map(\.kind), [.week, .fiveHours])
        XCTAssertEqual(read.fullest?.kind, .fiveHours)
    }

    func testASessionLimitIsTheFiveHoursAndTheFiveHourKeyDoesNotRepeatIt() throws {
        let fiveHour = #""five_hour": {"utilization": 100.0, "resets_at": "\#(reset)"}"#
        let limits = #"[\#(limit("session", 100)), \#(limit("weekly_all", 26)), \#(limit("weekly_scoped", 16, model: "Fable"))]"#
        let read = try usage(#"{\#(fiveHour), "limits": \#(limits)}"#)
        XCTAssertEqual(read.limits.map(\.kind), [.fiveHours, .week, .weekOnModel("Fable")])
        XCTAssertEqual(read.limits.map(\.percentUsed), [100, 26, 16])
        let alone = try usage(#"{"five_hour": null, "limits": [\#(limit("session", 40))]}"#)
        XCTAssertEqual(alone.limits.map(\.kind), [.fiveHours])
    }

    func testALimitOfAnUnknownKindCountsTowardTheRoom() throws {
        let read = try usage(#"{"limits": [\#(limit("weekly_all", 20)), \#(limit("monthly_all", 70))]}"#)
        XCTAssertEqual(read.limits.map(\.kind), [.week, .other("monthly_all")])
        XCTAssertEqual(read.room, 30)
    }

    func testAModelLimitWithoutAModelNameKeepsItsKind() throws {
        XCTAssertEqual(try usage(#"{"limits": [\#(limit("weekly_scoped", 5))]}"#).limits.map(\.kind), [.other("weekly_scoped")])
    }

    func testALimitWithoutAPercentIsLeftOut() throws {
        let read = try usage(#"{"limits": [{"kind": "weekly_all", "percent": null}, \#(limit("weekly_scoped", 5, model: "Fable"))]}"#)
        XCTAssertEqual(read.limits.map(\.kind), [.weekOnModel("Fable")])
    }

    func testAnAnswerWithoutAnyLimitHasNoRoom() throws {
        let read = try usage("{}")
        XCTAssertEqual(read.limits, [])
        XCTAssertNil(read.room)
    }

    func testAShareOutsideZeroToAHundredIsBroughtBackInside() throws {
        XCTAssertEqual(try usage(#"{"limits": [\#(limit("weekly_all", 104))]}"#).room, 0)
        XCTAssertEqual(try usage(#"{"limits": [\#(limit("weekly_all", -3))]}"#).room, 100)
    }

    func testAnAnswerThatIsNotAUsageAnswerIsRefused() {
        XCTAssertThrowsError(try usage("<html>Service unavailable</html>"))
        XCTAssertThrowsError(try usage(#"["not", "an", "object"]"#))
    }
}
