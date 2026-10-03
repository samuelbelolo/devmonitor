import Foundation

/// What a process is to the monitor: something to list, to see through, or to leave alone.
public enum ProcessRole: Equatable, Sendable {
    /// An app, a system process, an editor or a remote session: never listed, never signalled.
    case protected
    /// A coding agent session: never listed, never signalled, but its children are attributed to it.
    case agent(Agent)
    /// A shell someone types in: never signalled, and nothing above it is a service.
    case interactiveShell
    /// A shell that only runs a command or a script: part of the service it launches.
    case wrapperShell
    case regular

    private static let shells: Set<String> = ["zsh", "bash", "sh", "fish", "dash", "ksh", "tcsh", "nu"]
    private static let protectedNames: Set<String> = [
        "launchd", "loginwindow", "login", "sshd", "ssh-agent", "gpg-agent",
        "ssh", "mosh-client", "autossh",
        "tmux", "screen", "zellij",
        "vi", "vim", "nvim", "emacs", "hx", "nano", "less", "more", "man",
        "colima", "lima", "limactl", "vfkit", "ollama",
    ]
    private static let protectedNamePrefixes = ["qemu-system-", "emacs-"]
    private static let systemPrefixes = ["/System/", "/usr/libexec/", "/usr/sbin/", "/sbin/", "/Library/Apple/"]
    private static let bundleMarkers = [".xpc/Contents/", ".appex/Contents/"]
    private static let shellFlagsWithValue: Set<String> = ["--rcfile", "--init-file", "-o", "+o", "-O", "+O"]

    /// Returns the role of a process, from its executable path and its arguments.
    /// @example ProcessRole.of(claudeSession) // .agent(.claude)
    public static func of(_ process: ProcessSnapshot) -> ProcessRole {
        let name = process.name
        let path = process.executablePath
        if isInsideAnApp(path) || systemPrefixes.contains(where: path.hasPrefix) || bundleMarkers.contains(where: path.contains) {
            return .protected
        }
        if let agent = Agent.running(process) { return .agent(agent) }
        if protectedNames.contains(name) || protectedNamePrefixes.contains(where: name.hasPrefix) { return .protected }
        if shells.contains(name) { return runsACommand(process.arguments) ? .wrapperShell : .interactiveShell }
        return .regular
    }

    /// Whether the monitor may list and signal this process.
    public var isCandidate: Bool { self == .wrapperShell || self == .regular }

    /// Whether an executable belongs to an app bundle; a bundle nested in a framework, like Python.app, is a command-line tool.
    /// @example isInsideAnApp("/Applications/Cursor.app/Contents/MacOS/Cursor") // true
    private static func isInsideAnApp(_ path: String) -> Bool {
        guard let bundle = path.range(of: ".app/Contents/", options: .backwards) else { return false }
        return !path[..<bundle.lowerBound].contains(".framework/")
    }

    /// Whether a shell was started to run a command (`-c`) or a script, rather than to be typed in.
    /// @example runsACommand(["zsh", "-c", "pnpm dev"]) // true
    private static func runsACommand(_ arguments: [String]) -> Bool {
        var skipsNext = false
        for argument in arguments.dropFirst() {
            if skipsNext { skipsNext = false; continue }
            if shellFlagsWithValue.contains(argument) { skipsNext = true; continue }
            if argument.hasPrefix("--") || argument.hasPrefix("+") { continue }
            if !argument.hasPrefix("-") || argument.contains("c") { return true }
        }
        return false
    }
}
