import XCTest
@testable import DevMonitorCore

final class ProjectGrouperTests: XCTestCase {
    private let gigabyte: UInt64 = 1_073_741_824

    /// Builds a one-process service located in a project.
    /// @example service(1, project: "a", memory: 10).memoryBytes // 10
    private func service(_ pid: Int32, project: String, memory: UInt64, mcp: Bool = false) -> Service {
        DevMonitorCoreTests.service([snap(pid, parent: 1, path: "/bin/node", memory: memory)], project: project, mcp: mcp)
    }

    func testServicesOfTheSameProjectShareAGroupSortedByMemory() {
        let groups = ProjectGrouper.groups(services: [service(1, project: "a", memory: 10 * gigabyte), service(2, project: "b", memory: 50 * gigabyte), service(3, project: "a", memory: 5 * gigabyte)], containers: [])
        XCTAssertEqual(groups.map(\.name), ["b", "a"])
        XCTAssertEqual(groups[1].memoryBytes, 15 * gigabyte)
    }

    func testMcpServersFormTheirOwnGroupListedLast() {
        let groups = ProjectGrouper.groups(services: [service(1, project: "a", memory: 10), service(2, project: "a", memory: 900, mcp: true)], containers: [])
        XCTAssertEqual(groups.map(\.kind), [.project, .mcpServers])
        XCTAssertEqual(groups.map(\.name), ["a", "MCP servers"])
    }

    func testContainersJoinTheGroupOfTheirComposeDirectory() {
        let container = DockerContainer(id: "c1", name: "a-cache-1", projectRoot: "/home/a", projectName: "a", memoryBytes: 100)
        let groups = ProjectGrouper.groups(services: [service(1, project: "a", memory: 10)], containers: [container])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].memoryBytes, 110)
    }

    func testMcpServersWithTheSameLabelShareARow() {
        let rows = ProjectGrouper.groups(services: [service(1, project: "a", memory: 10, mcp: true), service(2, project: "b", memory: 30, mcp: true)], containers: [])[0].rows
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].services.count, 2)
        XCTAssertEqual(rows[0].memoryBytes, 40)
    }

    func testMergedRowListsAPortOnlyOnce() {
        let servers = [1, 2].map { DevMonitorCoreTests.service([snap($0, parent: 1, path: "/bin/node", ports: [24282, 9000])], mcp: true) }
        XCTAssertEqual(ProjectGrouper.groups(services: servers, containers: [])[0].rows[0].ports, [9000, 24282])
    }

    func testProjectServicesKeepOneRowEach() {
        let rows = ProjectGrouper.groups(services: [service(1, project: "a", memory: 10 * gigabyte), service(2, project: "a", memory: 30 * gigabyte)], containers: [])[0].rows
        XCTAssertEqual(rows.map(\.memoryBytes), [30 * gigabyte, 10 * gigabyte])
    }

    func testGroupsOfSimilarMemoryKeepAStableOrderBetweenScans() {
        let megabyte: UInt64 = 1_048_576
        let first = ProjectGrouper.groups(services: [service(1, project: "a", memory: 100 * megabyte), service(2, project: "b", memory: 101 * megabyte)], containers: [])
        let second = ProjectGrouper.groups(services: [service(1, project: "a", memory: 102 * megabyte), service(2, project: "b", memory: 99 * megabyte)], containers: [])
        XCTAssertEqual(first.map(\.name), second.map(\.name))
    }
}
