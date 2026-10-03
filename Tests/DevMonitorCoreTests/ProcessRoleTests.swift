import XCTest
@testable import DevMonitorCore

final class ProcessRoleTests: XCTestCase {
    /// Returns the role of a process given by its executable path and arguments.
    /// @example role("/usr/bin/ssh") // .protected
    private func role(_ path: String, _ args: [String] = []) -> ProcessRole {
        ProcessRole.of(snap(5, parent: 1, path: path, args: args))
    }

    func testProcessInsideAnAppBundleIsProtected() {
        XCTAssertEqual(ProcessRole.of(agentChain()[0]), .protected)
    }

    func testHelperInsideTheFrameworkOfAnAppIsProtected() {
        XCTAssertEqual(role("/Applications/Cursor.app/Contents/Frameworks/Electron Framework.framework/Helpers/chrome_crashpad_handler"), .protected)
    }

    func testFrameworkPythonIsRegularAlthoughItRunsFromABundle() {
        XCTAssertEqual(role("/opt/homebrew/Cellar/python@3.14/3.14.7/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python"), .regular)
        XCTAssertEqual(role("/Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/Resources/Python.app/Contents/MacOS/Python"), .regular)
    }

    func testSystemProcessesAndExtensionsAreProtected() {
        XCTAssertEqual(role("/usr/libexec/secd"), .protected)
        XCTAssertEqual(role("/System/Library/CoreServices/pbs"), .protected)
        XCTAssertEqual(role("/Users/me/Library/Tools/Sync.xpc/Contents/MacOS/Sync"), .protected)
        XCTAssertEqual(role("/Users/me/Library/Tools/Share.appex/Contents/MacOS/Share"), .protected)
    }

    func testRemoteSessionsEditorsAndMultiplexersAreProtected() {
        for path in ["/usr/bin/ssh", "/opt/homebrew/bin/mosh-client", "/opt/homebrew/bin/nvim", "/usr/bin/vim", "/opt/homebrew/bin/zellij", "/opt/homebrew/bin/tmux", "/usr/bin/login"] {
            XCTAssertEqual(role(path), .protected, path)
        }
    }

    func testVirtualMachineHostsAreProtected() {
        XCTAssertEqual(role("/opt/homebrew/bin/limactl"), .protected)
        XCTAssertEqual(role("/opt/homebrew/bin/qemu-system-aarch64"), .protected)
    }

    func testClaudeSessionIsAnAgent() {
        XCTAssertEqual(ProcessRole.of(agentChain()[1]), .agent(.claude))
    }

    func testClaudeInstalledAsAVersionedBinaryIsAnAgent() {
        XCTAssertEqual(role("/Users/me/.local/share/claude/versions/2.1.9", ["claude", "--resume"]), .agent(.claude))
    }

    func testAgentRunByAnInterpreterIsAnAgent() {
        XCTAssertEqual(role("/opt/homebrew/bin/node", ["node", "/opt/homebrew/lib/node_modules/@openai/codex/bin/codex.js"]), .agent(.codex))
        XCTAssertEqual(role("/opt/homebrew/bin/node", ["node", "--no-warnings", "/Users/me/.npm/_npx/1/node_modules/@anthropic-ai/claude-code/cli.js"]), .agent(.claude))
        XCTAssertEqual(role("/Users/me/.venv/bin/python3.12", ["python3.12", "/Users/me/.venv/bin/aider"]), .agent(.aider))
        XCTAssertEqual(role("/opt/homebrew/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python", ["python3", "/opt/homebrew/bin/aider"]), .agent(.aider))
    }

    func testOtherCodingAgentsAreAgents() {
        XCTAssertEqual(role("/opt/homebrew/bin/gemini"), .agent(.gemini))
        XCTAssertEqual(role("/Users/me/.local/bin/cursor-agent"), .agent(.cursorAgent))
        XCTAssertEqual(role("/Users/me/.opencode/bin/opencode"), .agent(.opencode))
    }

    func testScriptNamedAfterAnAgentDoesNotMakeAnyCommandAnAgent() {
        XCTAssertEqual(role("/usr/bin/tail", ["tail", "-f", "codex.log"]), .regular)
    }

    func testShellRunningACommandIsAWrapperShell() {
        XCTAssertEqual(ProcessRole.of(agentChain()[2]), .wrapperShell)
        XCTAssertEqual(role("/bin/bash", ["bash", "-lc", "pnpm dev"]), .wrapperShell)
        XCTAssertEqual(role("/bin/sh", ["sh", "./deploy.sh"]), .wrapperShell)
    }

    func testShellWithoutACommandIsInteractive() {
        XCTAssertEqual(role("/bin/zsh", ["-zsh"]), .interactiveShell)
        XCTAssertEqual(role("/bin/zsh", ["zsh", "-il"]), .interactiveShell)
        XCTAssertEqual(role("/bin/bash", ["bash", "--login"]), .interactiveShell)
        XCTAssertEqual(role("/opt/homebrew/bin/fish"), .interactiveShell)
        XCTAssertEqual(role("/bin/bash", ["bash", "--rcfile", "/tmp/nix-shell/rc"]), .interactiveShell)
    }

    func testNodeIsRegular() {
        XCTAssertEqual(ProcessRole.of(agentChain()[4]), .regular)
    }

    func testOnlyWrapperShellsAndRegularProcessesMayBeSignalled() {
        XCTAssertTrue(ProcessRole.regular.isCandidate)
        XCTAssertTrue(ProcessRole.wrapperShell.isCandidate)
        XCTAssertFalse(ProcessRole.interactiveShell.isCandidate)
        XCTAssertFalse(ProcessRole.agent(.claude).isCandidate)
        XCTAssertFalse(ProcessRole.protected.isCandidate)
    }
}
