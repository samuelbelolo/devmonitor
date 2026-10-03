import DevMonitorCore
import Foundation

/// Every sentence and label of the interface, in French or English. Sizes and durations come from `DisplayFormat`.
enum Strings {
    private static let french = AppLanguage.current == .french

    static let stop = french ? "Arrêter" : "Stop"
    static let confirm = french ? "Confirmer" : "Confirm"
    static let force = french ? "Forcer" : "Force quit"
    static let orphan = french ? "orphelin" : "orphan"
    static let nothingRunning = french ? "Rien ne tourne." : "Nothing is running."
    static let launchAtLogin = french ? "Lancer à l'ouverture de session" : "Launch at login"
    static let quit = french ? "Quitter" : "Quit"
    static let mcpServers = french ? "Serveurs MCP" : "MCP servers"

    /// Returns the caption next to the total, with the number of projects.
    /// @example Strings.usedBy(projects: 4) // "used by 4 projects"
    static func usedBy(projects count: Int) -> String {
        french ? "utilisés par \(count) projet\(count > 1 ? "s" : "")" : "used by \(count) project\(count > 1 ? "s" : "")"
    }

    /// Returns a count of processes.
    /// @example Strings.processes(3) // "3 processes"
    static func processes(_ count: Int) -> String {
        french ? "\(count) process" : "\(count) process\(count > 1 ? "es" : "")"
    }

    /// Returns a count of containers.
    /// @example Strings.containers(6) // "6 containers"
    static func containers(_ count: Int) -> String {
        french ? "\(count) conteneur\(count > 1 ? "s" : "")" : "\(count) container\(count > 1 ? "s" : "")"
    }

    /// Returns the tag of a service that has done nothing for a duration.
    /// @example Strings.idle(for: "13 h") // "idle 13 h"
    static func idle(for duration: String) -> String {
        french ? "au repos \(duration)" : "idle \(duration)"
    }

    /// Returns the caption naming the agent that started a service.
    /// @example Strings.startedBy("Claude") // "started by Claude"
    static func startedBy(_ agent: String) -> String {
        french ? "lancé par \(agent)" : "started by \(agent)"
    }

    /// Returns the title of the button that stops every idle service, with the memory it frees.
    /// @example Strings.stopIdle(count: 3, memory: "416 MB") // "Stop 3 idle · frees 416 MB"
    static func stopIdle(count: Int, memory: String) -> String {
        french ? "Arrêter \(count) au repos · libère \(memory)" : "Stop \(count) idle · frees \(memory)"
    }

    static let byProject = french ? "Par projet" : "By project"
    static let versions = "Versions"
    static let outsideProjects = french ? "Hors projet" : "Outside any project"
    static let working = french ? "travaille" : "working"
    static let waiting = french ? "attend" : "waiting"
    static let upToDate = french ? "à jour" : "up to date"
    static let versionUnreadable = french ? "version illisible" : "version unreadable"
    static let latestUnknown = french ? "dernière version inconnue" : "latest version unknown"
    static let copy = french ? "Copier" : "Copy"
    static let copied = french ? "Copié" : "Copied"
    static let noAgent = french ? "Aucun agent installé." : "No coding agent installed."
    static let checkVersions = french ? "Vérifier les nouvelles versions" : "Check for new versions"
    static let animateLogo = french ? "Animer le logo quand un agent travaille" : "Animate the logo while an agent works"

    /// Returns the caption next to the number of sessions.
    /// @example Strings.sessionsCaption(working: 3) // "agent sessions · 3 working"
    static func sessionsCaption(working: Int) -> String {
        let busy = working == 0
            ? (french ? "toutes en attente" : "all waiting")
            : (french ? "\(working) travaille\(working > 1 ? "nt" : "")" : "\(working) working")
        return (french ? "sessions d'agent · " : "agent sessions · ") + busy
    }

    /// Returns the count of open sessions of one agent.
    /// @example Strings.openSessions(8) // "8 open sessions"
    static func openSessions(_ count: Int) -> String {
        if count == 0 { return french ? "aucune session" : "no session" }
        return french ? "\(count) session\(count > 1 ? "s" : "") ouverte\(count > 1 ? "s" : "")" : "\(count) open session\(count > 1 ? "s" : "")"
    }

    /// Returns the tag of an agent with a newer version published.
    /// @example Strings.available("2.1.291") // "2.1.291 available"
    static func available(_ version: String) -> String {
        french ? "\(version) disponible" : "\(version) available"
    }

    /// Returns the note on sessions that still run an older version than the installed one.
    /// @example Strings.toRestart(1, oldest: "2.1.287") // "1 session on 2.1.287 · restart to update"
    static func toRestart(_ count: Int, oldest: String) -> String {
        french
            ? "\(count) session\(count > 1 ? "s" : "") en \(oldest) · à relancer"
            : "\(count) session\(count > 1 ? "s" : "") on \(oldest) · restart to update"
    }
}
