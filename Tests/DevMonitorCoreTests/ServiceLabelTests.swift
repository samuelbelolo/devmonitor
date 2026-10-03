import XCTest
@testable import DevMonitorCore

final class ServiceLabelTests: XCTestCase {
    func testInterpreterShowsItsScriptAndFirstArgument() {
        let process = snap(1, parent: 0, path: "/opt/homebrew/bin/node", args: ["node", "/repo/node_modules/.bin/next", "dev", "--port", "3000"])
        XCTAssertEqual(ServiceLabel.of(process), "next dev")
    }

    func testRetitledProcessShowsItsTitle() {
        let process = snap(1, parent: 0, path: "/Users/me/.n/bin/node", args: ["next-server (v16.3.4)"])
        XCTAssertEqual(ServiceLabel.of(process), "next-server (v16.3.4)")
    }

    func testPlainCommandShowsItsFirstArgument() {
        let process = snap(1, parent: 0, path: "/opt/homebrew/bin/pnpm", args: ["pnpm", "dev"])
        XCTAssertEqual(ServiceLabel.of(process), "pnpm dev")
    }

    func testCommandWithoutArgumentsShowsItsName() {
        XCTAssertEqual(ServiceLabel.of(snap(1, parent: 0, path: "/usr/bin/redis-server")), "redis-server")
    }

    func testRetitledLauncherShowsThePackageItRuns() {
        let process = snap(1, parent: 0, path: "/Users/me/.n/bin/node", args: ["npm exec @zenrows/mcp   "])
        XCTAssertEqual(ServiceLabel.of(process), "@zenrows/mcp")
    }

    func testGenericScriptNameIsReplacedByItsPackageDirectory() {
        let process = snap(1, parent: 0, path: "/Users/me/.n/bin/node", args: ["node", "packages/mcp-server/dist/index.js"])
        XCTAssertEqual(ServiceLabel.of(process), "mcp-server")
    }

    func testLauncherWordsAndFlagValuesAreSkipped() {
        let process = snap(1, parent: 0, path: "/opt/homebrew/bin/uv", args: ["uv", "tool", "uvx", "--from", "serena-agent", "serena", "start-mcp-server", "--context", "claude-code"])
        XCTAssertEqual(ServiceLabel.of(process), "serena start-mcp-server")
    }

    func testPathArgumentsAreLeftOut() {
        let process = snap(1, parent: 0, path: "/opt/homebrew/bin/rtk", args: ["rtk", "proxy", "npx", "jest", "--config", "./test/jest-e2e.ts", "test/lease.e2e-spec.ts"])
        XCTAssertEqual(ServiceLabel.of(process), "jest")
    }

    func testRetitledProcessWithBlankLeftoverArgumentsStillShowsItsTitle() {
        let process = snap(1, parent: 0, path: "/Users/me/.n/bin/node", args: ["npm exec chrome-devtools-mcp@1.1.1", "", ""])
        XCTAssertEqual(ServiceLabel.of(process), "chrome-devtools-mcp@1.1.1")
    }

    /// Returns the label of a command given as its executable path followed by its arguments.
    /// @example label("/usr/bin/redis-cli", "-a", "PASSWORD", "monitor") // "redis-cli monitor"
    private func label(_ path: String, _ arguments: String...) -> String {
        ServiceLabel.of(snap(1, parent: 0, path: path, args: [(path as NSString).lastPathComponent] + arguments))
    }

    func testValueOfAnUnknownFlagIsNeverShown() {
        XCTAssertEqual(label("/opt/homebrew/bin/node", "/repo/node_modules/.bin/vite", "--port", "5173"), "vite")
        XCTAssertEqual(label("/opt/homebrew/bin/node", "app.js", "--api-key", "sk-live-SECRET"), "app")
        XCTAssertEqual(label("/usr/bin/redis-cli", "-a", "PASSWORD", "monitor"), "redis-cli monitor")
        XCTAssertEqual(label("/opt/homebrew/bin/cloudflared", "--token", "eyJSECRET", "tunnel", "run"), "cloudflared tunnel")
        XCTAssertEqual(label("/usr/bin/curl", "-H", "Authorization: Bearer TOKEN", "https://example.com/y"), "curl")
        XCTAssertEqual(label("/opt/homebrew/bin/uvx", "--from", "pkg", "tool", "--api-key", "KEY123"), "tool")
    }

    func testAssignmentsAndConnectionStringsAreNeverShown() {
        XCTAssertEqual(label("/opt/homebrew/bin/psql", "host=db password=PW"), "psql")
        XCTAssertEqual(label("/usr/bin/env", "DATABASE_URL=postgres:u:PW", "node", "x.js"), "node x.js")
        XCTAssertEqual(label("/opt/homebrew/bin/psql", "postgres://user:pw@db/app"), "psql")
    }

    func testTokenThatLooksLikeACredentialIsNeverShown() {
        XCTAssertEqual(label("/opt/homebrew/bin/wrangler", "ghp_a1B2c3D4e5F6g7H8i9J0k1L2m3N4o5P6q7R8", "tail"), "wrangler tail")
        XCTAssertEqual(label("/opt/homebrew/bin/wrangler", "a1B2c3D4e5F6g7H8i9J0k1L2m3N4"), "wrangler")
    }

    func testFlagWithoutAValueKeepsTheWordThatFollowsIt() {
        XCTAssertEqual(label("/opt/homebrew/bin/npx", "-y", "@modelcontextprotocol/server-github"), "@modelcontextprotocol/server-github")
        XCTAssertEqual(label("/opt/homebrew/bin/node", "--inspect", "server.js"), "server")
        XCTAssertEqual(label("/usr/bin/python3", "-m", "uvicorn", "app.main:app", "--reload", "--port", "8000"), "uvicorn app.main:app")
    }

    func testPackageManagerShowsTheScriptItRuns() {
        XCTAssertEqual(label("/opt/homebrew/bin/npm", "run", "dev"), "npm dev")
        XCTAssertEqual(label("/opt/homebrew/bin/pnpm", "--filter", "web", "dev"), "pnpm dev")
        XCTAssertEqual(label("/opt/homebrew/bin/node", "/opt/homebrew/bin/pnpm", "run", "worker"), "pnpm worker")
    }

    func testLabelIsCleanedAndCut() {
        let process = snap(1, parent: 0, path: "/Users/me/.n/bin/node", args: ["worker\n" + String(repeating: "x", count: 100)])
        XCTAssertEqual(ServiceLabel.of(process).count, 48)
        XCTAssertFalse(ServiceLabel.of(process).contains("\n"))
    }

    func testFrameworkPythonShowsTheScriptItRuns() {
        let process = snap(1, parent: 0, path: "/opt/homebrew/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python", args: ["python3", "manage.py", "runserver"])
        XCTAssertEqual(ServiceLabel.of(process), "manage runserver")
    }
}
