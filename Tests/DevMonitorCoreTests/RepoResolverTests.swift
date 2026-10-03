import XCTest
@testable import DevMonitorCore

final class RepoResolverTests: XCTestCase {
    private var home = ""

    override func setUp() {
        home = makeTempDirectory()
        write(home + "/acme/shop/.git/HEAD")
        write(home + "/acme/shop/packages/ui/package.json", "{}")
        write(home + "/acme/worktrees/feat-123/.git", "gitdir: \(home)/acme/shop/.git/worktrees/feat-123\n")
        write(home + "/acme/worktrees/feat-123/packages/ui/package.json", "{}")
        write(home + "/tools/my-tool/app/package.json", #"{"name": "my-tool"}"#)
        write(home + "/notes/readme.txt")
    }

    func testDirectoryInsideARepoResolvesToTheRepoRoot() {
        let location = RepoResolver(home: home).resolve(home + "/acme/shop/packages")
        XCTAssertEqual(location?.root, home + "/acme/shop")
        XCTAssertEqual(location?.name, "shop")
        XCTAssertNil(location?.worktree)
    }

    func testWorktreeResolvesToTheMainRepoWithItsWorktreeName() {
        let location = RepoResolver(home: home).resolve(home + "/acme/worktrees/feat-123")
        XCTAssertEqual(location?.root, home + "/acme/shop")
        XCTAssertEqual(location?.worktree, "feat-123")
    }

    func testPackageIsThePathBelowTheWorktreeRoot() {
        let location = RepoResolver(home: home).resolve(home + "/acme/worktrees/feat-123/packages/ui")
        XCTAssertEqual(location?.package, "packages/ui")
    }

    func testDirectoryWithoutGitFallsBackToThePackageName() {
        let location = RepoResolver(home: home).resolve(home + "/tools/my-tool/app")
        XCTAssertEqual(location?.root, home + "/tools/my-tool/app")
        XCTAssertEqual(location?.name, "my-tool")
    }

    func testDirectoryWithoutGitOrManifestIsNotAProject() {
        XCTAssertNil(RepoResolver(home: home).resolve(home + "/notes"))
    }

    func testDirectoryOutsideHomeIsNotAProject() {
        XCTAssertNil(RepoResolver(home: home).resolve("/"))
    }

    func testWorktreeWithARelativeGitPointerResolvesToTheMainRepo() {
        write(home + "/acme/worktrees/feat-rel/.git", "gitdir: ../../shop/.git/worktrees/feat-rel\n")
        let location = RepoResolver(home: home).resolve(home + "/acme/worktrees/feat-rel")
        XCTAssertEqual(location?.root, home + "/acme/shop")
        XCTAssertEqual(location?.worktree, "feat-rel")
    }

    func testWorktreeOfABareRepositoryIsNamedAfterTheRepository() {
        write(home + "/acme/api.git/HEAD")
        write(home + "/acme/api-feat/.git", "gitdir: \(home)/acme/api.git/worktrees/api-feat\n")
        let location = RepoResolver(home: home).resolve(home + "/acme/api-feat")
        XCTAssertEqual(location?.root, home + "/acme/api.git")
        XCTAssertEqual(location?.name, "api")
        XCTAssertEqual(location?.worktree, "api-feat")
    }

    func testWorktreesAroundAHiddenBareRepositoryShareTheFolderThatHoldsThem() {
        write(home + "/acme/site/.bare/HEAD")
        write(home + "/acme/site/main/.git", "gitdir: \(home)/acme/site/.bare/worktrees/main\n")
        let location = RepoResolver(home: home).resolve(home + "/acme/site/main")
        XCTAssertEqual(location?.root, home + "/acme/site")
        XCTAssertEqual(location?.name, "site")
        XCTAssertEqual(location?.worktree, "main")
    }

    func testGitPointerLeadingOutsideTheHomeFolderIsNotFollowed() {
        write(home + "/acme/odd/.git", "gitdir: /etc/elsewhere/.git/worktrees/odd\n")
        XCTAssertEqual(RepoResolver(home: home).resolve(home + "/acme/odd")?.root, home + "/acme/odd")
    }

    func testProjectCreatedAfterAFirstLookupIsFound() {
        let resolver = RepoResolver(home: home)
        XCTAssertNil(resolver.resolve(home + "/notes"))
        write(home + "/notes/.git/HEAD")
        XCTAssertEqual(resolver.resolve(home + "/notes")?.name, "notes")
    }

    func testClearingTheCacheForgetsACheckoutThatWasRemoved() throws {
        let resolver = RepoResolver(home: home)
        XCTAssertNotNil(resolver.resolve(home + "/tools/my-tool/app"))
        try FileManager.default.removeItem(atPath: home + "/tools/my-tool/app/package.json")
        XCTAssertNotNil(resolver.resolve(home + "/tools/my-tool/app"))
        resolver.clearCache()
        XCTAssertNil(resolver.resolve(home + "/tools/my-tool/app"))
    }

    func testPathIsStandardisedBeforeItIsResolved() {
        let resolver = RepoResolver(home: home)
        XCTAssertEqual(resolver.resolve(home + "/acme/shop/packages/../packages/ui")?.package, "packages/ui")
        XCTAssertNil(resolver.resolve(home + "/../../etc"))
    }

    func testProjectNameFromAManifestIsCleaned() {
        write(home + "/tools/odd/package.json", #"{"name": "odd\ntool\u001b"}"#)
        XCTAssertEqual(RepoResolver(home: home).resolve(home + "/tools/odd")?.name, "odd tool")
    }
}
