import XCTest
@testable import DevMonitorCore

final class ContainerLocatorTests: XCTestCase {
    private var home = ""

    override func setUp() {
        home = makeTempDirectory()
        write(home + "/acme/shop/.git/HEAD")
        write(home + "/acme/worktrees/feat-123/.git", "gitdir: \(home)/acme/shop/.git/worktrees/feat-123\n")
        write(home + "/acme/worktrees/feat-123/docker/compose.yml")
    }

    /// Locates one container started from a directory.
    /// @example located(from: "/srv/stack") // []
    private func located(from directory: String) -> [DockerContainer] {
        let container = DockerContainer(id: "abc123", name: "feat-cache-1", projectRoot: directory, projectName: "feat", memoryBytes: 10)
        return ContainerLocator.locate([container], resolver: RepoResolver(home: home))
    }

    func testContainerJoinsTheRepositoryItsComposeFileLivesIn() {
        let container = located(from: home + "/acme/worktrees/feat-123/docker").first
        XCTAssertEqual(container?.projectRoot, home + "/acme/shop")
        XCTAssertEqual(container?.projectName, "shop")
    }

    func testContainerStartedOutsideAnyProjectIsLeftOut() {
        XCTAssertTrue(located(from: "/srv/stack").isEmpty)
    }
}
