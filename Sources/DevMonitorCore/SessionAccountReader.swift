import Foundation

/// Finds the account a running agent session draws on: the one its config folder is signed in with, unless the
/// session is sent elsewhere (a proxy, an API key, a cloud provider). Reads only the account's two ids, never its email.
/// Each file is read again only when it changed, and a file caught mid-write keeps the account read before.
public final class SessionAccountReader: @unchecked Sendable {
    /// The variables that decide where a session's sign-in lives, or that send it away from its account.
    public static let variables = Set(["HOME", "CLAUDE_CONFIG_DIR", "CODEX_HOME", "OPENAI_BASE_URL"]).union(claudeDiversions)
    /// Set to a non-empty value, any of these makes Claude Code draw on something other than its signed-in account.
    private static let claudeDiversions: Set<String> = [
        "ANTHROPIC_BASE_URL", "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "CLAUDE_CODE_OAUTH_TOKEN",
        "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX",
    ]
    private let modified: (String) -> Date?
    private let contents: (String) -> Data?
    private var parsed: [String: (modified: Date, value: String?)] = [:]

    /// Creates a reader of the files on this Mac, or of the given ones in the tests.
    /// @example SessionAccountReader().accountKey(agent: .claude, environment: ["HOME": NSHomeDirectory()])
    public init(modified: ((String) -> Date?)? = nil, contents: ((String) -> Data?)? = nil) {
        self.modified = modified ?? { try? FileManager.default.attributesOfItem(atPath: $0)[.modificationDate] as? Date }
        self.contents = contents ?? { FileManager.default.contents(atPath: $0) }
    }

    /// Returns the key of the tracked account a session draws on; nil when it cannot be told or goes elsewhere.
    /// @example reader.accountKey(agent: .claude, environment: ["HOME": "/Users/me"]) // "1111…:6666…"
    public func accountKey(agent: Agent, environment: [String: String]?) -> String? {
        guard let environment, let home = environment["HOME"], !home.isEmpty else { return nil }
        switch agent {
        case .claude: return claudeKey(environment, home: home)
        case .codex: return codexKey(environment, home: home)
        default: return nil
        }
    }

    /// Returns the Claude account of a session, from `.claude.json` beside its settings.
    /// @example claudeKey(["HOME": "/h"], home: "/h") // "acc-1:org-1"
    private func claudeKey(_ environment: [String: String], home: String) -> String? {
        guard !Self.claudeDiversions.contains(where: { !(environment[$0] ?? "").isEmpty }) else { return nil }
        let folder = environment["CLAUDE_CONFIG_DIR"].flatMap { $0.isEmpty ? nil : $0 }
        let settings = (folder ?? home + "/.claude") + "/settings.json"
        if let diverted = cached(settings, read: Self.divertingSettings), diverted == "yes" { return nil }
        return cached((folder ?? home) + "/.claude.json", read: Self.claudeAccount)
    }

    /// Returns the Codex account of a session, from `auth.json` in its Codex home.
    /// @example codexKey(["HOME": "/h"], home: "/h") // "codex:cx-1:"
    private func codexKey(_ environment: [String: String], home: String) -> String? {
        guard (environment["OPENAI_BASE_URL"] ?? "").isEmpty else { return nil }
        let folder = environment["CODEX_HOME"].flatMap { $0.isEmpty ? nil : $0 } ?? home + "/.codex"
        if let provider = cached(folder + "/config.toml", read: Self.codexProvider), provider != "openai" { return nil }
        return cached(folder + "/auth.json", read: Self.codexAccount)
    }

    /// Returns what `read` finds in a file, parsing it again only when it changed; a file that no longer parses keeps
    /// the value it had. Nil when the file is not there or never held a value.
    /// @example cached("/h/.claude.json", read: claudeAccount) // "acc-1:org-1"
    private func cached(_ path: String, read: (Data) -> String??) -> String? {
        guard let date = modified(path) else {
            parsed[path] = nil
            return nil
        }
        if let known = parsed[path], known.modified == date { return known.value }
        guard let data = contents(path), let value = read(data) else { return parsed[path]?.value }
        parsed[path] = (date, value)
        return value
    }

    /// Returns "acc:org" from a `.claude.json`; .some(nil) when it holds no sign-in, nil when it does not parse.
    /// @example claudeAccount(Data(#"{"oauthAccount":{"accountUuid":"a","organizationUuid":"o"}}"#.utf8)) // "a:o"
    private static func claudeAccount(_ data: Data) -> String?? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let account = root["oauthAccount"] as? [String: Any], let id = account["accountUuid"] as? String,
              let organization = account["organizationUuid"] as? String, !id.isEmpty else { return .some(nil) }
        return "\(id):\(organization)"
    }

    /// Returns "yes" when Claude settings send sessions elsewhere through their `env` block, "no" otherwise.
    /// @example divertingSettings(Data(#"{"env":{"ANTHROPIC_BASE_URL":"http://x"}}"#.utf8)) // "yes"
    private static func divertingSettings(_ data: Data) -> String?? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let env = root["env"] as? [String: Any] ?? [:]
        return claudeDiversions.contains { !((env[$0] as? String) ?? "").isEmpty } ? "yes" : "no"
    }

    /// Returns "codex:id:" from a Codex `auth.json` signed in with ChatGPT; .some(nil) for an API key or no sign-in.
    /// @example codexAccount(Data(#"{"tokens":{"account_id":"cx"}}"#.utf8)) // "codex:cx:"
    private static func codexAccount(_ data: Data) -> String?? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if (root["auth_mode"] as? String) == "apikey" { return .some(nil) }
        guard let tokens = root["tokens"] as? [String: Any], let id = tokens["account_id"] as? String, !id.isEmpty else { return .some(nil) }
        return AccountID(provider: .codex, account: id, organization: "", email: "").key
    }

    /// Returns the model provider a Codex `config.toml` names at its top, "openai" when it names none.
    /// @example codexProvider(Data("model_provider = \"ollama\"\n".utf8)) // "ollama"
    private static func codexProvider(_ data: Data) -> String?? {
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            let text = line.trimmingCharacters(in: .whitespaces)
            if text.hasPrefix("[") { break }
            let parts = text.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, parts[0] == "model_provider" { return parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
        }
        return "openai"
    }
}
