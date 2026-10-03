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
}
