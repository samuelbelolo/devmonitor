import XCTest
@testable import DevMonitorCore

final class ProjectScanTests: XCTestCase {
    func testScanGroupsServicesAndContainersAndListsEveryProcessSeen() {
        let home = makeTempDirectory()
        write(home + "/repo/.git/HEAD")
        let processes = agentChain().map { process in
            snap(process.pid, parent: process.ppid, path: process.executablePath, args: process.arguments,
                 cwd: process.workingDirectory.map { _ in home + "/repo" }, memory: process.memoryBytes)
        }
        let container = DockerContainer(id: "abc123", name: "repo-cache-1", projectRoot: home + "/repo", projectName: "repo", memoryBytes: 10)
        let scan = ProjectScan.run(processes: processes, containers: [container], resolver: RepoResolver(home: home), now: 160)
        XCTAssertEqual(scan.groups.map(\.kind), [.project, .mcpServers])
        XCTAssertEqual(scan.groups[0].services.map(\.root.pid), [40])
        XCTAssertEqual(scan.groups[0].containers.map(\.name), ["repo-cache-1"])
        XCTAssertEqual(scan.agentSessions.map(\.agent), [.claude])
        XCTAssertEqual(scan.processIdentities, ["10-100", "20-100", "30-100", "40-100", "50-100", "60-100"])
    }
}
