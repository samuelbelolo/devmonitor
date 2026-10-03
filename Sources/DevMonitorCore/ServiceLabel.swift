import Foundation

/// The short name shown for a service. A command line can carry secrets, so only command words are ever shown:
/// never the value of a flag, an assignment, a URL or anything that looks like a credential.
public enum ServiceLabel {
    private enum Following { case kept, dropped, droppedUnlessScript }

    private static let interpreters: Set<String> = ["node", "bun", "deno", "tsx", "ruby"]
    private static let packageManagers: Set<String> = ["npm", "pnpm", "yarn", "bun"]
    private static let runVerbs: Set<String> = ["run", "run-script"]
    private static let executeVerbs: Set<String> = ["exec", "dlx", "x"]
    /// Commands that only run another one, with the words of their own to skip before it.
    private static let launchers: [String: Set<String>] = ["uv": ["tool", "uvx", "run"], "uvx": [], "npx": [], "bunx": [], "rtk": ["proxy", "npx"], "env": []]
    private static let flagsWithValue: Set<String> = ["--from", "--config", "-p", "--package", "-r", "--require", "--import", "--loader"]
    /// Flags after which the next word is still part of the command: switches, `--`, and `-m`, whose module is what runs.
    private static let flagsWithoutValue: Set<String> = ["-m", "--", "-y", "--yes", "-s", "--silent", "-q", "--quiet", "-v", "--verbose", "--bun"]
    private static let scriptExtensions = [".js", ".mjs", ".cjs", ".ts", ".tsx", ".py", ".rb", ".sh"]
    private static let credentialPrefixes = ["sk-", "sk_", "pk_", "rk_", "eyJ", "ghp_", "gho_", "ghs_", "github_pat_", "glpat-", "xoxb-", "xoxp-", "AKIA"]
    private static let genericNames: Set<String> = ["index", "main", "cli", "server", "app", "start", "daemon", "dist", "build", "bin", "src", "lib", "out", ".bin"]
    private static let limit = 48

    /// Returns a short label for a process: what a launcher or interpreter runs, or its title when it renamed itself.
    /// @example ServiceLabel.of(nodeRunningNext) // "next dev"
    public static func of(_ process: ProcessSnapshot) -> String {
        DisplayText.clean(label(words(of: process)), limit: limit)
    }

    /// Returns the label for the words of a command, the first one being the command itself.
    /// @example label(["pnpm", "--filter", "web", "dev"]) // "pnpm dev"
    private static func label(_ words: [String]) -> String {
        var head = words[0]
        var rest = shown(Array(words.dropFirst()))
        if interprets(head), let script = rest.first, packageManagers.contains(fileName(script)) {
            head = fileName(script)
            rest.removeFirst()
        }
        if packageManagers.contains(head), let verb = rest.first {
            if runVerbs.contains(verb) { return ([head] + rest.dropFirst().prefix(1)).joined(separator: " ") }
            if executeVerbs.contains(verb) { return target(Array(rest.dropFirst()), fallback: head) }
        }
        if let skipped = launchers[head] { return target(Array(rest.drop { skipped.contains($0) }), fallback: head) }
        if interprets(head) { return target(rest, fallback: head) }
        guard let first = rest.first else { return head }
        return first.contains("/") ? head : head + " " + first
    }

    /// Returns the name of what a launcher or interpreter runs, with its first argument when it is not a path.
    /// @example target(["/repo/node_modules/.bin/next", "dev"], fallback: "node") // "next dev"
    private static func target(_ rest: [String], fallback: String) -> String {
        guard let first = rest.first else { return fallback }
        let second = rest.dropFirst().first.flatMap { $0.contains("/") ? nil : $0 }
        return [describe(first), second].compactMap { $0 }.joined(separator: " ")
    }

    /// Returns the command words: the title split on spaces when the process renamed itself, else its name and arguments.
    /// @example words(of: retitled) // ["npm", "exec", "@scope/mcp"]
    private static func words(of process: ProcessSnapshot) -> [String] {
        let arguments = process.arguments.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let title = arguments.first ?? ""
        if arguments.count == 1, title.contains(" ") {
            return title.split(separator: " ").map(String.init)
        }
        if arguments.count == 1, !title.isEmpty, !title.contains("/") { return [title] }
        return [process.name] + arguments.dropFirst()
    }

    /// Keeps the words that may be shown: drops flags, the value that follows a flag, and anything sensitive.
    /// @example shown(["--from", "serena-agent", "serena", "--api-key", "KEY123"]) // ["serena"]
    private static func shown(_ tokens: [String]) -> [String] {
        var result: [String] = []
        var following = Following.kept
        for token in tokens {
            if token.hasPrefix("-") {
                following = self.following(token)
                continue
            }
            let isValue = following == .dropped || (following == .droppedUnlessScript && !looksLikeAScript(token))
            following = .kept
            if !isValue, !isSensitive(token) { result.append(token) }
        }
        return result
    }

    /// Tells what to do with the word after a flag: unless the flag is known, it is taken for the flag's value.
    /// @example following("--api-key") // .droppedUnlessScript
    private static func following(_ flag: String) -> Following {
        if flag.contains("=") || flagsWithoutValue.contains(flag) { return .kept }
        return flagsWithValue.contains(flag) ? .dropped : .droppedUnlessScript
    }

    /// Whether a word is a script or a path rather than the value of an option.
    /// @example looksLikeAScript("server.js") // true
    private static func looksLikeAScript(_ token: String) -> Bool {
        token.contains("/") || scriptExtensions.contains(where: token.hasSuffix)
    }

    /// Whether a word may hold a secret: an assignment, a URL, a known credential prefix, or a long random-looking token.
    /// @example isSensitive("DATABASE_URL=postgres:u:pw") // true
    private static func isSensitive(_ token: String) -> Bool {
        if token.contains("=") || token.contains("://") || credentialPrefixes.contains(where: token.hasPrefix) { return true }
        let isOpaque = token.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "_+-/".contains($0)) }
        return token.count >= 24 && isOpaque && token.filter(\.isNumber).count >= 4
    }

    /// Whether a command runs the script given as its first argument; framework Python runs as "Python".
    /// @example interprets("python3.12") // true
    private static func interprets(_ command: String) -> Bool {
        interpreters.contains(command) || command.lowercased().hasPrefix("python")
    }

    /// Returns the file name of a path without its extension.
    /// @example fileName("/opt/homebrew/bin/pnpm.cjs") // "pnpm"
    private static func fileName(_ path: String) -> String {
        ((path as NSString).lastPathComponent as NSString).deletingPathExtension
    }

    /// Returns a readable name for a script path: its file name, or its package directory when the file name is generic.
    /// @example describe("packages/mcp-server/dist/index.js") // "mcp-server"
    private static func describe(_ target: String) -> String {
        let isPath = target.hasPrefix("/") || target.hasPrefix(".") || scriptExtensions.contains(where: target.hasSuffix)
        guard isPath else { return target }
        let parts = target.split(separator: "/").map(String.init)
        let names = parts.dropLast().reversed() as [String]
        let file = ((parts.last ?? target) as NSString).deletingPathExtension
        return ([file] + names).first { !genericNames.contains($0) } ?? file
    }
}
