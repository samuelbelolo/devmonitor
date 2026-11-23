@testable import DevMonitorCore
import XCTest

final class SessionAccountReaderTests: XCTestCase {
    /// Files kept in memory, each with the date it last changed.
    private final class Files: @unchecked Sendable {
        var contents: [String: (text: String, modified: Date)] = [:]
        var reads = 0

        /// Puts a file in place, changed at `second`.
        /// @example files.put("/h/.claude.json", "{}", at: 1)
        func put(_ path: String, _ text: String, at second: TimeInterval = 1) {
            contents[path] = (text, Date(timeIntervalSince1970: second))
        }

        /// Returns a reader that reads these files only.
        /// @example files.reader().accountKey(agent: .claude, environment: ["HOME": "/h"])
        func reader() -> SessionAccountReader {
            SessionAccountReader(
                modified: { [unowned self] in self.contents[$0]?.modified },
                contents: { [unowned self] in self.reads += 1; return self.contents[$0].map { Data($0.text.utf8) } })
        }
    }

    private let claudeSignIn = #"{"oauthAccount": {"accountUuid": "acc-1", "organizationUuid": "org-1", "emailAddress": "a@example.com"}, "projects": {}}"#

    func testAClaudeSessionDrawsOnTheAccountOfItsHomeConfig() {
        let files = Files()
        files.put("/h/.claude.json", claudeSignIn)
        XCTAssertEqual(files.reader().accountKey(agent: .claude, environment: ["HOME": "/h"]), "acc-1:org-1")
    }

    func testAClaudeSessionWithItsOwnConfigFolderReadsThatFolder() {
        let files = Files()
        files.put("/h/.claude.json", claudeSignIn)
        files.put("/h/work/.claude.json", #"{"oauthAccount": {"accountUuid": "acc-2", "organizationUuid": "org-2"}}"#)
        let key = files.reader().accountKey(agent: .claude, environment: ["HOME": "/h", "CLAUDE_CONFIG_DIR": "/h/work"])
        XCTAssertEqual(key, "acc-2:org-2")
    }

    func testAnEmptyApiKeyIsIgnoredButASetOneSendsTheSessionElsewhere() {
        let files = Files()
        files.put("/h/.claude.json", claudeSignIn)
        let reader = files.reader()
        XCTAssertEqual(reader.accountKey(agent: .claude, environment: ["HOME": "/h", "ANTHROPIC_API_KEY": ""]), "acc-1:org-1")
        XCTAssertNil(reader.accountKey(agent: .claude, environment: ["HOME": "/h", "ANTHROPIC_API_KEY": "sk-ant-x"]))
        XCTAssertNil(reader.accountKey(agent: .claude, environment: ["HOME": "/h", "ANTHROPIC_BASE_URL": "http://localhost:20128"]))
    }

    func testAProxySetInTheUserSettingsSendsTheSessionElsewhere() {
        let files = Files()
        files.put("/h/.claude.json", claudeSignIn)
        files.put("/h/.claude/settings.json", #"{"env": {"ANTHROPIC_BASE_URL": "http://localhost:20128", "NO_COLOR": "1"}}"#)
        XCTAssertNil(files.reader().accountKey(agent: .claude, environment: ["HOME": "/h"]))
    }

    func testOtherSettingsLeaveTheSessionOnItsAccount() {
        let files = Files()
        files.put("/h/.claude.json", claudeSignIn)
        files.put("/h/.claude/settings.json", #"{"env": {"NO_COLOR": "1", "ANTHROPIC_API_KEY": ""}}"#)
        XCTAssertEqual(files.reader().accountKey(agent: .claude, environment: ["HOME": "/h"]), "acc-1:org-1")
    }

    func testAnUnreadableEnvironmentOrAMissingSignInTellsNothing() {
        let files = Files()
        files.put("/h/.claude.json", #"{"projects": {}}"#)
        let reader = files.reader()
        XCTAssertNil(reader.accountKey(agent: .claude, environment: nil))
        XCTAssertNil(reader.accountKey(agent: .claude, environment: [:]))
        XCTAssertNil(reader.accountKey(agent: .claude, environment: ["HOME": "/h"]))
        XCTAssertNil(reader.accountKey(agent: .claude, environment: ["HOME": "/nowhere"]))
    }

    func testAFileCaughtMidWriteKeepsTheLastAccountRead() {
        let files = Files()
        files.put("/h/.claude.json", claudeSignIn, at: 1)
        let reader = files.reader()
        XCTAssertEqual(reader.accountKey(agent: .claude, environment: ["HOME": "/h"]), "acc-1:org-1")
        files.put("/h/.claude.json", #"{"oauthAccount": {"accountUu"#, at: 2)
        XCTAssertEqual(reader.accountKey(agent: .claude, environment: ["HOME": "/h"]), "acc-1:org-1")
    }

    func testAFileIsReadAgainOnlyWhenItChanged() {
        let files = Files()
        files.put("/h/.claude.json", claudeSignIn, at: 1)
        let reader = files.reader()
        _ = reader.accountKey(agent: .claude, environment: ["HOME": "/h"])
        let reads = files.reads
        _ = reader.accountKey(agent: .claude, environment: ["HOME": "/h"])
        XCTAssertEqual(files.reads, reads)
        files.put("/h/.claude.json", #"{"oauthAccount": {"accountUuid": "acc-3", "organizationUuid": "org-3"}}"#, at: 2)
        XCTAssertEqual(reader.accountKey(agent: .claude, environment: ["HOME": "/h"]), "acc-3:org-3")
    }

    func testACodexSessionDrawsOnTheChatGPTAccountOfItsHome() {
        let files = Files()
        files.put("/h/.codex/auth.json", #"{"auth_mode": "chatgpt", "OPENAI_API_KEY": null, "tokens": {"account_id": "cx-1"}}"#)
        files.put("/h/codex2/auth.json", #"{"tokens": {"account_id": "cx-2"}}"#)
        let reader = files.reader()
        XCTAssertEqual(reader.accountKey(agent: .codex, environment: ["HOME": "/h"]), "codex:cx-1:")
        XCTAssertEqual(reader.accountKey(agent: .codex, environment: ["HOME": "/h", "CODEX_HOME": "/h/codex2"]), "codex:cx-2:")
    }

    func testACodexSessionOnAnApiKeyOrAnotherProviderDrawsOnNoAccount() {
        let files = Files()
        files.put("/h/.codex/auth.json", #"{"auth_mode": "apikey", "OPENAI_API_KEY": "sk-x", "tokens": {"account_id": "cx-1"}}"#)
        files.put("/h/c2/auth.json", #"{"tokens": {"account_id": "cx-2"}}"#)
        files.put("/h/c2/config.toml", "model = \"o4\"\nmodel_provider = \"ollama\"\n")
        files.put("/h/c3/auth.json", #"{"tokens": {"account_id": "cx-3"}}"#)
        files.put("/h/c3/config.toml", "model_provider = \"openai\"\n")
        let reader = files.reader()
        XCTAssertNil(reader.accountKey(agent: .codex, environment: ["HOME": "/h"]))
        XCTAssertNil(reader.accountKey(agent: .codex, environment: ["HOME": "/h", "CODEX_HOME": "/h/c2"]))
        XCTAssertEqual(reader.accountKey(agent: .codex, environment: ["HOME": "/h", "CODEX_HOME": "/h/c3"]), "codex:cx-3:")
        XCTAssertNil(reader.accountKey(agent: .codex, environment: ["HOME": "/h", "OPENAI_BASE_URL": "http://localhost:1"]))
    }

    func testTheKeysMatchTheTrackedAccounts() {
        XCTAssertEqual(AccountID(account: "acc-1", organization: "org-1", email: "").key, "acc-1:org-1")
        XCTAssertEqual(AccountID(provider: .codex, account: "cx-1", organization: "", email: "").key, "codex:cx-1:")
    }

    func testOtherAgentsDrawOnNoTrackedAccount() {
        XCTAssertNil(Files().reader().accountKey(agent: .gemini, environment: ["HOME": "/h"]))
    }
}
