import DevMonitorCore
import XCTest

final class KeychainVaultTests: XCTestCase {
    /// The calls a vault made to `security`, and what each was answered.
    private final class Calls: @unchecked Sendable {
        var made: [(arguments: [String], input: String?)] = []
        var answers: [CommandResult?] = []

        /// Records a call and returns the next answer.
        /// @example calls.answer(["-i"], "add-generic-password …")
        func answer(_ arguments: [String], _ input: String?) -> CommandResult? {
            made.append((arguments, input))
            return answers.isEmpty ? nil : answers.removeFirst()
        }
    }

    /// Returns a vault whose `security` calls are recorded and answered by `calls`.
    /// @example vault(calls).save(signIn)
    private func vault(_ calls: Calls) -> KeychainVault {
        KeychainVault(servicePrefix: "local.devmonitor.test") { calls.answer($0, $1) }
    }

    /// The text `security -w` prints for a sign-in: its JSON, in base64.
    /// @example stored(signIn) // "eyJhY2Nlc3NUb2tlbiI6…\n"
    private func stored(_ signIn: SignIn) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(signIn).base64EncodedString() + "\n"
    }

    func testASaveSendsTheSecretOnStandardInputAndReadsItBack() throws {
        let calls = Calls()
        let signIn = UsageFakes.signIn("a1", "r1")
        calls.answers = [CommandResult(status: 0, output: ""), CommandResult(status: 0, output: try stored(signIn))]
        try vault(calls).save(signIn)
        XCTAssertEqual(calls.made.count, 2)
        XCTAssertEqual(calls.made[0].arguments, ["-i"])
        let line = try XCTUnwrap(calls.made[0].input)
        XCTAssertTrue(line.hasPrefix("add-generic-password -U -s local.devmonitor.test.claude -a \(signIn.account.key) -w "))
        XCTAssertFalse(line.contains("a1"), "the token travels in base64 only")
        XCTAssertFalse(calls.made.flatMap(\.arguments).contains { $0.contains("a1") || $0.contains("r1") })
        XCTAssertEqual(calls.made[1].arguments, ["find-generic-password", "-s", "local.devmonitor.test.claude", "-a", signIn.account.key, "-w"])
    }

    func testASaveThatDoesNotReadBackTheSameIsRefused() throws {
        let calls = Calls()
        calls.answers = [CommandResult(status: 0, output: ""), CommandResult(status: 0, output: try stored(UsageFakes.signIn("old", "old")))]
        XCTAssertThrowsError(try vault(calls).save(UsageFakes.signIn("a1", "r1")))
    }

    func testAFailedOrStuckWriteIsRefused() {
        let failing = Calls()
        failing.answers = [CommandResult(status: 45, output: "")]
        XCTAssertThrowsError(try vault(failing).save(UsageFakes.signIn("a1", "r1")))
        let stuck = Calls()
        stuck.answers = [nil]
        XCTAssertThrowsError(try vault(stuck).save(UsageFakes.signIn("a1", "r1")))
    }

    func testAMissingItemIsNoSignInAndAnUnreadableOneIsAnError() throws {
        let missing = Calls()
        missing.answers = [CommandResult(status: 44, output: "")]
        XCTAssertNil(try vault(missing).signIn(for: "k"))
        let locked = Calls()
        locked.answers = [nil]
        XCTAssertThrowsError(try vault(locked).signIn(for: "k"))
        let garbled = Calls()
        garbled.answers = [CommandResult(status: 0, output: "not base64 at all\n")]
        XCTAssertThrowsError(try vault(garbled).signIn(for: "k"))
    }

    func testAStoredSignInIsReadWithItsDates() throws {
        let calls = Calls()
        let signIn = UsageFakes.signIn("a1", "r1")
        calls.answers = [CommandResult(status: 0, output: try stored(signIn))]
        XCTAssertEqual(try vault(calls).signIn(for: signIn.account.key), signIn)
    }

    func testACodexSignInIsKeptUnderItsOwnService() throws {
        let calls = Calls()
        let codex = SignIn(accessToken: "a", refreshToken: "r", accessExpiresAt: UsageFakes.start, expiresAt: nil,
                           account: AccountID(provider: .codex, account: "acct", organization: "", email: "dev@example.com"))
        calls.answers = [CommandResult(status: 0, output: ""), CommandResult(status: 0, output: try stored(codex))]
        try vault(calls).save(codex)
        XCTAssertTrue(calls.made[0].input?.hasPrefix("add-generic-password -U -s local.devmonitor.test.codex -a codex:acct: -w ") == true)
        XCTAssertEqual(calls.made[1].arguments, ["find-generic-password", "-s", "local.devmonitor.test.codex", "-a", "codex:acct:", "-w"])
    }

    func testAClaudeSignInKeptByTheFirstVersionIsStillRead() throws {
        // The first version kept no provider and no renewal date.
        let firstVersion = #"{"accessExpiresAt":"2026-11-15T00:00:00Z","accessToken":"a1","account":{"account":"11111111-2222-3333-4444-555555555555","email":"dev@example.com","organization":"66666666-7777-8888-9999-000000000000"},"expiresAt":"2026-12-13T00:00:00Z","refreshToken":"r1"}"#
        let calls = Calls()
        calls.answers = [CommandResult(status: 0, output: Data(firstVersion.utf8).base64EncodedString() + "\n")]
        let signIn = try XCTUnwrap(try vault(calls).signIn(for: UsageFakes.account.key))
        XCTAssertEqual(signIn.account, UsageFakes.account)
        XCTAssertEqual(signIn.account.provider, .claude)
        XCTAssertNil(signIn.renewAfter)
        XCTAssertEqual(calls.made[0].arguments, ["find-generic-password", "-s", "local.devmonitor.test.claude", "-a", UsageFakes.account.key, "-w"])
    }

    func testRemovingAnItemThatIsNotThereIsFine() throws {
        let calls = Calls()
        calls.answers = [CommandResult(status: 44, output: "")]
        try vault(calls).remove(key: "k")
        XCTAssertEqual(calls.made.first?.arguments, ["delete-generic-password", "-s", "local.devmonitor.test.claude", "-a", "k"])
    }

    /// Runs only with DEVMON_LIVE_KEYCHAIN=1: writes, reads and removes a test item of the login keychain, under a
    /// service the app never uses.
    func testTheRealKeychainKeepsASignIn() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DEVMON_LIVE_KEYCHAIN"] == "1", "live keychain test")
        let vault = KeychainVault(servicePrefix: "local.devmonitor.live-test")
        let signIn = UsageFakes.signIn("live-access-" + UUID().uuidString, "live-refresh-" + UUID().uuidString)
        defer { try? vault.remove(key: signIn.account.key) }
        try vault.save(signIn)
        XCTAssertEqual(try vault.signIn(for: signIn.account.key), signIn)
        try vault.remove(key: signIn.account.key)
        XCTAssertNil(try vault.signIn(for: signIn.account.key))
    }
}
