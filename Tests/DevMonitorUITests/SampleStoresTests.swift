import DevMonitorCore
import XCTest
@testable import DevMonitorUI

/// The documentation's images are rendered on a developer's Mac: a sample store that read that Mac would publish
/// its real projects. These tests fail on any Mac that runs something if a sample store scans, reads or asks.
@MainActor
final class SampleStoresTests: XCTestCase {
    /// Returns a store showing the sample scan with a swap that is fine.
    /// @example sampleStore().agentSessions.count // 9
    private func sampleStore() -> MonitorStore {
        MonitorStore(sample: SampleData.scan(swap: .fine), startedAt: nil)
    }

    func testASampleStoreKeepsItsScanWhenAWindowOpensAndARefreshIsAsked() async {
        let store = sampleStore()
        let groups = store.groups
        store.setWindow(.memory, isOpen: true)
        store.setWindow(.agents, isOpen: true)
        await store.refresh()
        // A refresh loop started by the open windows would have scanned by now.
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(store.groups, groups)
        XCTAssertEqual(store.agentSessions.count, 9)
        XCTAssertEqual(store.workingCount, 4)
        XCTAssertEqual(store.swap?.state, .fine)
    }

    func testASampleStoreStopsNothing() {
        let store = sampleStore()
        let group = store.groups[0]
        store.stop(group)
        XCTAssertFalse(group.services.contains(where: store.isStopping))
    }

    func testASampleVersionStoreKeepsItsReports() async {
        let versions = VersionStore(sample: SampleData.versions)
        await versions.refresh(fetchingLatest: true)
        await versions.refreshInstalled()
        XCTAssertEqual(versions.reports.map(\.agent), [.claude, .codex])
        XCTAssertEqual(versions.reports.first?.installed?.text, "2.1.288")
        XCTAssertTrue(versions.isOutdated(.claude))
    }

    func testASampleExtensionStoreKeepsItsReport() async {
        let extensions = ExtensionStore(sample: SampleData.extensions, checkedAt: nil, versions: VersionStore(sample: SampleData.versions))
        await extensions.windowOpened()
        await extensions.refresh(fetchingUpstream: true)
        XCTAssertEqual(extensions.report, SampleData.extensions)
        XCTAssertFalse(extensions.isChecking)
    }

    func testTheSampleMacShowsTheFiguresOfTheDemo() {
        let store = sampleStore()
        XCTAssertEqual(DisplayFormat.memory(store.totalBytes, language: .english), "19.0 GB")
        XCTAssertEqual(store.groups.map(\.name), ["web-app", "my-tool", "shop-front", "MCP servers"])
        XCTAssertEqual(store.groups.last?.processCount, 88)
        XCTAssertEqual(store.idleServices.map(\.label), ["vite"])
        let updateAll = SampleData.extensions.updateAll
        XCTAssertEqual(updateAll?.skills, 6)
        XCTAssertEqual(updateAll?.plugins, 1)
    }

    func testEachSwapStateOfTheSampleMacIsTheOneAskedFor() {
        for state in [SwapState.fine, .high, .critical] {
            XCTAssertEqual(SampleData.scan(swap: state).swap?.state, state)
        }
    }
}
