import XCTest
@testable import DevMonitorCore

final class FileWatcherTests: XCTestCase {
    func testAFileRewrittenInPlaceIsTold() throws {
        let folder = makeTempDirectory()
        let lock = folder + "/.skill-lock.json"
        write(lock, "{}")
        let changed = expectation(description: "changed")
        changed.assertForOverFulfill = false
        let watcher = FileWatcher(files: [lock], latency: 0.1) { changed.fulfill() }
        XCTAssertNotNil(watcher)
        // FSEvents starts telling a moment after the stream starts.
        Thread.sleep(forTimeInterval: 0.5)
        // Truncated then written, the way the `skills` tool writes it: the folder itself does not change.
        let handle = try XCTUnwrap(FileHandle(forWritingAtPath: lock))
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data(#"{"skills":{}}"#.utf8))
        try handle.close()
        wait(for: [changed], timeout: 5)
        withExtendedLifetime(watcher) {}
    }

    func testAnotherFileOfTheFolderIsNotTold() {
        let folder = makeTempDirectory()
        let lock = folder + "/.skill-lock.json"
        write(lock, "{}")
        // FSEvents may still tell a change made just before the stream starts: the lock's own creation here.
        Thread.sleep(forTimeInterval: 1)
        let changed = expectation(description: "changed")
        changed.isInverted = true
        let watcher = FileWatcher(files: [lock], latency: 0.1) { changed.fulfill() }
        Thread.sleep(forTimeInterval: 0.5)
        write(folder + "/skills/audit/SKILL.md", "# audit")
        wait(for: [changed], timeout: 1.5)
        withExtendedLifetime(watcher) {}
    }

    func testNothingIsWatchedWithoutAFolder() {
        XCTAssertNil(FileWatcher(files: ["/nowhere/at/all/.skill-lock.json"]) {})
    }
}
